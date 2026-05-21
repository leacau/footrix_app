import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

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

	if (lockHoursBefore < 1 || lockHoursBefore > 72) {
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
