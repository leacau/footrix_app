import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { processFinishedMatchPoints } from './calculatePointsOnMatchFinish';
import { syncFifaMatches } from './fifaApi';

function requireAdmin(context: functions.https.CallableContext): void {
	if (!context.auth) {
		throw new functions.https.HttpsError('unauthenticated', 'No autenticado');
	}

	if (context.auth.token.admin !== true) {
		throw new functions.https.HttpsError(
			'permission-denied',
			'No tenes permisos de administrador',
		);
	}
}

function readString(value: unknown, field: string, maxLength = 80): string {
	const text = typeof value === 'string' ? value.trim() : '';
	if (!text || text.length > maxLength) {
		throw new functions.https.HttpsError(
			'invalid-argument',
			`${field} invalido`,
		);
	}
	return text;
}

function readScore(value: unknown, field: string): number {
	if (!Number.isInteger(value) || (value as number) < 0 || (value as number) > 30) {
		throw new functions.https.HttpsError(
			'invalid-argument',
			`${field} invalido`,
		);
	}
	return value as number;
}

function readIntInRange(
	value: unknown,
	field: string,
	min: number,
	max: number,
): number {
	if (!Number.isInteger(value) || (value as number) < min || (value as number) > max) {
		throw new functions.https.HttpsError(
			'invalid-argument',
			`${field} invalido`,
		);
	}
	return value as number;
}

export const adminCreateMatch = functions.https.onCall(async (data, context) => {
	requireAdmin(context);

	const homeTeam = readString(data.homeTeam, 'Equipo local');
	const awayTeam = readString(data.awayTeam, 'Equipo visitante');
	const phase = readString(data.phase, 'Fase');
	const kickoffMillis = data.kickoffMillis;
	const lockHoursBefore = Number.isInteger(data.lockHoursBefore)
		? (data.lockHoursBefore as number)
		: 12;

	if (
		typeof kickoffMillis !== 'number' ||
		!Number.isFinite(kickoffMillis) ||
		kickoffMillis < Date.now() - 60 * 60 * 1000
	) {
		throw new functions.https.HttpsError('invalid-argument', 'Fecha invalida');
	}

	if (lockHoursBefore < 0 || lockHoursBefore > 72) {
		throw new functions.https.HttpsError(
			'invalid-argument',
			'Bloqueo invalido',
		);
	}

	const doc = await admin.firestore().collection('matches').add({
		homeTeam,
		awayTeam,
		phase,
		kickoff: admin.firestore.Timestamp.fromMillis(kickoffMillis),
		status: 'scheduled',
		homeScore: null,
		awayScore: null,
		lockHoursBefore,
		createdAt: admin.firestore.FieldValue.serverTimestamp(),
		updatedAt: admin.firestore.FieldValue.serverTimestamp(),
	});

	return { success: true, matchId: doc.id };
});

export const adminFinishMatch = functions.https.onCall(async (data, context) => {
	requireAdmin(context);

	const matchId = readString(data.matchId, 'Partido');
	const homeScore = readScore(data.homeScore, 'Goles local');
	const awayScore = readScore(data.awayScore, 'Goles visitante');
	const matchRef = admin.firestore().collection('matches').doc(matchId);
	const matchDoc = await matchRef.get();

	if (!matchDoc.exists) {
		throw new functions.https.HttpsError('not-found', 'Partido no encontrado');
	}

	await matchRef.update({
		status: 'finished',
		homeScore,
		awayScore,
		finishedAt: admin.firestore.FieldValue.serverTimestamp(),
		updatedAt: admin.firestore.FieldValue.serverTimestamp(),
	});

	return { success: true };
});

export const adminToggleUserStatus = functions.https.onCall(
	async (data, context) => {
		requireAdmin(context);

		const userId = readString(data.userId, 'Usuario', 128);
		if (typeof data.isActive !== 'boolean') {
			throw new functions.https.HttpsError(
				'invalid-argument',
				'Estado invalido',
			);
		}

		await admin.firestore().collection('users').doc(userId).update({
			isActive: data.isActive,
			updatedAt: admin.firestore.FieldValue.serverTimestamp(),
		});

		return { success: true };
	},
);

export const adminUpdatePredictionSettings = functions.https.onCall(
	async (data, context) => {
		requireAdmin(context);
		const lockHoursBefore = readIntInRange(
			data.lockHoursBefore,
			'Horas de cierre',
			0,
			168,
		);
		const db = admin.firestore();

		await db.collection('app_config').doc('predictions').set(
			{
				lockHoursBefore,
				updatedAt: admin.firestore.FieldValue.serverTimestamp(),
				updatedBy: context.auth!.uid,
			},
			{ merge: true },
		);

		return {
			success: true,
			lockHoursBefore,
		};
	},
);

export const adminUpdateTriviaSettings = functions.https.onCall(
	async (data, context) => {
		requireAdmin(context);
		const dailyQuestionLimit = readIntInRange(
			data.dailyQuestionLimit,
			'Preguntas por dia',
			1,
			100,
		);

		await admin.firestore().collection('app_config').doc('trivia').set(
			{
				dailyQuestionLimit,
				updatedAt: admin.firestore.FieldValue.serverTimestamp(),
				updatedBy: context.auth!.uid,
			},
			{ merge: true },
		);

		return { success: true, dailyQuestionLimit };
	},
);

function addDays(date: Date, days: number): Date {
	const copy = new Date(date);
	copy.setUTCDate(copy.getUTCDate() + days);
	return copy;
}

function startOfUtcDay(date: Date): Date {
	return new Date(
		Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()),
	);
}

function endOfUtcDay(date: Date): Date {
	const start = startOfUtcDay(date);
	return new Date(start.getTime() + 24 * 60 * 60 * 1000 - 1000);
}

export const adminSyncAndRecalculateRecentPoints = functions
	.runWith({ timeoutSeconds: 540 })
	.https.onCall(async (_data, context) => {
		requireAdmin(context);
		const db = admin.firestore();
		const today = startOfUtcDay(new Date());
		const yesterday = addDays(today, -1);

		const yesterdaySync = await syncFifaMatches(yesterday, endOfUtcDay(yesterday));
		const todaySync = await syncFifaMatches(today, endOfUtcDay(today));

		const cutoff = admin.firestore.Timestamp.fromDate(addDays(new Date(), -7));
		const finishedMatches = await db
			.collection('matches')
			.where('status', '==', 'finished')
			.where('kickoff', '>=', cutoff)
			.limit(300)
			.get();

		let predictionsProcessed = 0;
		let totalDelta = 0;
		for (const matchDoc of finishedMatches.docs) {
			const result = await processFinishedMatchPoints(matchDoc.id);
			predictionsProcessed += result.updatedCount;
			totalDelta += result.totalDelta;
		}

		return {
			success: true,
			matchesSynced:
				yesterdaySync.matchesSynced + todaySync.matchesSynced,
			leaguesSynced:
				yesterdaySync.leaguesSynced + todaySync.leaguesSynced,
			matchesRecalculated: finishedMatches.size,
			predictionsProcessed,
			totalDelta,
		};
	});

export const adminRepairUserDocuments = functions
	.runWith({ timeoutSeconds: 540 })
	.https.onCall(async (_data, context) => {
		requireAdmin(context);
		const db = admin.firestore();
		let repaired = 0;
		let pageToken: string | undefined;

		do {
			const page = await admin.auth().listUsers(1000, pageToken);
			pageToken = page.pageToken;

			for (const user of page.users) {
				const userRef = db.collection('users').doc(user.uid);
				const doc = await userRef.get();
				const existing = doc.data();
				const patch: admin.firestore.DocumentData = {
					uid: user.uid,
					updatedAt: admin.firestore.FieldValue.serverTimestamp(),
				};

				if (!existing?.createdAt) {
					patch.createdAt = admin.firestore.FieldValue.serverTimestamp();
				}
				if (!existing?.email && user.email) patch.email = user.email;
				if (!existing?.displayName && user.displayName) {
					patch.displayName = user.displayName;
				}
				if (!existing?.photoURL && user.photoURL) patch.photoURL = user.photoURL;
				if (typeof existing?.totalPoints !== 'number') patch.totalPoints = 0;
				if (typeof existing?.triviaPoints !== 'number') patch.triviaPoints = 0;
				if (typeof existing?.triviaStreak !== 'number') patch.triviaStreak = 0;
				if (typeof existing?.triviaBestStreak !== 'number') {
					patch.triviaBestStreak = 0;
				}
				if (typeof existing?.triviaAnswered !== 'number') {
					patch.triviaAnswered = 0;
				}
				if (!('country' in (existing ?? {}))) patch.country = null;
				if (!('province' in (existing ?? {}))) patch.province = null;
				if (!('city' in (existing ?? {}))) patch.city = null;
				if (!Array.isArray(existing?.privateGroups)) patch.privateGroups = [];

				await userRef.set(patch, { merge: true });
				repaired++;
			}
		} while (pageToken);

		return { success: true, repaired };
	});
