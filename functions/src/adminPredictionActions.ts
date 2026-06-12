import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

import { processFinishedMatchPoints } from './calculatePointsOnMatchFinish';
import { recalculateWorldCupUserScore } from './worldCupActions';

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

function optionalString(value: unknown): string {
	return typeof value === 'string' ? value.trim() : '';
}

function optionalMillis(value: unknown): number | null {
	return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

export async function recalculateNormalUserPoints(userId: string) {
	const db = admin.firestore();
	const predictions = await db
		.collection('predictions')
		.where('userId', '==', userId)
		.get();
	let totalPoints = 0;
	const leaguePoints = new Map<string, number>();
	const matchIds = predictions.docs
		.map((doc) => doc.data().matchId)
		.filter((id): id is string => typeof id === 'string');
	const matchDocs =
		matchIds.length > 0
			? await db.getAll(
					...matchIds.map((id) => db.collection('matches').doc(id)),
				)
			: [];
	const matchesById = new Map<string, admin.firestore.DocumentData>();
	for (const match of matchDocs) {
		if (match.exists) matchesById.set(match.id, match.data()!);
	}
	const writer = db.bulkWriter();
	for (const prediction of predictions.docs) {
		const data = prediction.data();
		const match = matchesById.get(data.matchId);
		let points = typeof data.pointsEarned === 'number' ? data.pointsEarned : 0;
		if (
			match?.status === 'finished' &&
			typeof match.homeScore === 'number' &&
			typeof match.awayScore === 'number'
		) {
			const homeGuess = typeof data.homeGuess === 'number' ? data.homeGuess : 0;
			const awayGuess = typeof data.awayGuess === 'number' ? data.awayGuess : 0;
			points =
				homeGuess === match.homeScore && awayGuess === match.awayScore
					? 3
					: (homeGuess > awayGuess && match.homeScore > match.awayScore) ||
						  (homeGuess < awayGuess && match.homeScore < match.awayScore) ||
						  (homeGuess === awayGuess && match.homeScore === match.awayScore)
						? 1
						: 0;
			writer.update(prediction.ref, {
				pointsEarned: points,
				status: 'graded',
				gradedAt: admin.firestore.FieldValue.serverTimestamp(),
				pointsCalculationVersion: 2,
				suppressPointsNotification: true,
			});
		}
		totalPoints += points;
		const leagueId = match?.leagueId;
		if (leagueId) {
			leaguePoints.set(leagueId, (leaguePoints.get(leagueId) ?? 0) + points);
		}
	}
	await writer.close();
	const userRef = db.collection('users').doc(userId);
	const user = await userRef.get();
	const leagueStats = {
		...((user.data()?.leagueStats as Record<string, unknown> | undefined) ?? {}),
	};
	for (const [leagueId, value] of Object.entries(leagueStats)) {
		if (typeof value === 'object' && value != null) {
			leagueStats[leagueId] = {
				...(value as Record<string, unknown>),
				points: leaguePoints.get(leagueId) ?? 0,
			};
		}
	}
	for (const [leagueId, points] of leaguePoints.entries()) {
		leagueStats[leagueId] = {
			...((leagueStats[leagueId] as Record<string, unknown> | undefined) ?? {}),
			points,
		};
	}
	await userRef.set(
		{
			totalPoints,
			leagueStats,
			updatedAt: admin.firestore.FieldValue.serverTimestamp(),
		},
		{ merge: true },
	);
}

export const adminListPredictions = functions
	.runWith({ timeoutSeconds: 120 })
	.https.onCall(async (data, context) => {
		requireAdmin(context);
		const db = admin.firestore();
		const userId = optionalString(data.userId);
		const leagueId = optionalString(data.leagueId);
		const mode = optionalString(data.mode) || 'all';
		const fromMillis = optionalMillis(data.fromMillis);
		const toMillis = optionalMillis(data.toMillis);
		const usersSnap = await db.collection('users').get();
		const users = new Map(
			usersSnap.docs.map((doc) => [
				doc.id,
				{
					displayName: doc.data().displayName ?? 'Anonimo',
					email: doc.data().email ?? '',
				},
			]),
		);
		const rows: Record<string, unknown>[] = [];

		if (mode === 'all' || mode === 'normal') {
			const predictions = userId
				? await db
						.collection('predictions')
						.where('userId', '==', userId)
						.limit(1000)
						.get()
				: await db.collection('predictions').limit(1000).get();
			const matchIds = [
				...new Set(
					predictions.docs
						.map((doc) => doc.data().matchId)
						.filter((id): id is string => typeof id === 'string'),
				),
			];
			const matches =
				matchIds.length > 0
					? await db.getAll(
							...matchIds.map((id) => db.collection('matches').doc(id)),
						)
					: [];
			const matchesById = new Map(
				matches.filter((doc) => doc.exists).map((doc) => [doc.id, doc.data()!]),
			);
			for (const doc of predictions.docs) {
				const prediction = doc.data();
				const match = matchesById.get(prediction.matchId);
				if (!match) continue;
				if (leagueId && match.leagueId !== leagueId) continue;
				const kickoff = match.kickoff as admin.firestore.Timestamp | undefined;
				const dateMillis = kickoff?.toMillis() ?? prediction.kickoffTime ?? 0;
				if (fromMillis != null && dateMillis < fromMillis) continue;
				if (toMillis != null && dateMillis > toMillis) continue;
				const profile = users.get(prediction.userId) ?? {
					displayName: 'Anonimo',
					email: '',
				};
				rows.push({
					id: `normal:${doc.id}`,
					mode: 'normal',
					userId: prediction.userId,
					...profile,
					matchId: prediction.matchId,
					homeTeam: match.homeTeam ?? 'Local',
					awayTeam: match.awayTeam ?? 'Visitante',
					leagueId: match.leagueId ?? '',
					competitionName: match.competitionName ?? '',
					dateMillis,
					homeGuess: prediction.homeGuess ?? 0,
					awayGuess: prediction.awayGuess ?? 0,
					points: prediction.pointsEarned ?? 0,
				});
			}
		}

		if (mode === 'all' || mode === 'worldCup') {
			const worldDocs = userId
				? [
						await db
							.collection('world_cup_predictions')
							.doc(userId)
							.get(),
					].filter((doc) => doc.exists)
				: (await db.collection('world_cup_predictions').get()).docs;
			const matchesSnap = await db
				.collection('matches')
				.where('leagueId', '==', 'copa-mundial-de-la-fifa')
				.get();
			const matchesById = new Map(
				matchesSnap.docs.map((doc) => [doc.id, doc.data()]),
			);
			for (const userPrediction of worldDocs) {
				const profile = users.get(userPrediction.id) ?? {
					displayName: 'Anonimo',
					email: '',
				};
				const picks =
					(userPrediction.data()?.matchPredictions as
						| Record<string, Record<string, unknown>>
						| undefined) ?? {};
				for (const [matchId, pick] of Object.entries(picks)) {
					const match = matchesById.get(matchId);
					if (!match) continue;
					if (leagueId && leagueId !== 'copa-mundial-de-la-fifa') continue;
					const kickoff = match.kickoff as admin.firestore.Timestamp | undefined;
					const dateMillis = kickoff?.toMillis() ?? 0;
					if (fromMillis != null && dateMillis < fromMillis) continue;
					if (toMillis != null && dateMillis > toMillis) continue;
					rows.push({
						id: `worldCup:${userPrediction.id}:${matchId}`,
						mode: 'worldCup',
						userId: userPrediction.id,
						...profile,
						matchId,
						homeTeam: match.homeTeam ?? match.placeHolderA ?? 'Local',
						awayTeam: match.awayTeam ?? match.placeHolderB ?? 'Visitante',
						leagueId: 'copa-mundial-de-la-fifa',
						competitionName: 'Mundial 2026',
						dateMillis,
						homeGuess: pick.homeGuess ?? 0,
						awayGuess: pick.awayGuess ?? 0,
						points: null,
					});
				}
			}
		}

		rows.sort((a, b) => Number(b.dateMillis ?? 0) - Number(a.dateMillis ?? 0));
		return { rows: rows.slice(0, 1000) };
	});

export const adminDeletePredictions = functions
	.runWith({ timeoutSeconds: 300 })
	.https.onCall(async (data, context) => {
		requireAdmin(context);
		const ids = Array.isArray(data.ids)
			? (data.ids as unknown[])
					.filter((id): id is string => typeof id === 'string')
					.slice(0, 1000)
			: [];
		if (ids.length === 0) {
			throw new functions.https.HttpsError(
				'invalid-argument',
				'Selecciona predicciones',
			);
		}
		const db = admin.firestore();
		const affectedNormal = new Set<string>();
		const affectedWorld = new Set<string>();
		const writer = db.bulkWriter();
		const worldChanges = new Map<string, Set<string>>();
		for (const id of ids) {
			if (id.startsWith('normal:')) {
				const docId = id.substring('normal:'.length);
				const doc = await db.collection('predictions').doc(docId).get();
				if (doc.exists && typeof doc.data()?.userId === 'string') {
					affectedNormal.add(doc.data()!.userId);
					writer.delete(doc.ref);
				}
			} else if (id.startsWith('worldCup:')) {
				const parts = id.split(':');
				if (parts.length >= 3) {
					const uid = parts[1];
					const matchId = parts.slice(2).join(':');
					affectedWorld.add(uid);
					const set = worldChanges.get(uid) ?? new Set<string>();
					set.add(matchId);
					worldChanges.set(uid, set);
				}
			}
		}
		await writer.close();
		for (const [uid, matchIds] of worldChanges.entries()) {
			const ref = db.collection('world_cup_predictions').doc(uid);
			const doc = await ref.get();
			const picks = {
				...((doc.data()?.matchPredictions as Record<string, unknown> | undefined) ??
					{}),
			};
			for (const matchId of matchIds) delete picks[matchId];
			await ref.set(
				{
					matchPredictions: picks,
					predictionCount: Object.keys(picks).length,
					updatedAt: admin.firestore.FieldValue.serverTimestamp(),
				},
				{ merge: true },
			);
		}
		for (const uid of affectedNormal) await recalculateNormalUserPoints(uid);
		for (const uid of affectedWorld) await recalculateWorldCupUserScore(uid);
		return { success: true, deleted: ids.length };
	});

export const adminUpdatePrediction = functions.https.onCall(
	async (data, context) => {
		requireAdmin(context);
		const id = optionalString(data.id);
		const homeGuess = data.homeGuess;
		const awayGuess = data.awayGuess;
		if (
			!id ||
			!Number.isInteger(homeGuess) ||
			!Number.isInteger(awayGuess) ||
			(homeGuess as number) < 0 ||
			(awayGuess as number) < 0 ||
			(homeGuess as number) > 30 ||
			(awayGuess as number) > 30
		) {
			throw new functions.https.HttpsError(
				'invalid-argument',
				'Prediccion invalida',
			);
		}
		const db = admin.firestore();
		if (id.startsWith('normal:')) {
			const docId = id.substring('normal:'.length);
			const ref = db.collection('predictions').doc(docId);
			const doc = await ref.get();
			if (!doc.exists) {
				throw new functions.https.HttpsError(
					'not-found',
					'Prediccion no encontrada',
				);
			}
			await ref.update({
				homeGuess,
				awayGuess,
				status: 'pending',
				pointsEarned: admin.firestore.FieldValue.delete(),
				gradedAt: admin.firestore.FieldValue.delete(),
				adminEditedAt: admin.firestore.FieldValue.serverTimestamp(),
			});
			const matchId = doc.data()?.matchId;
			const userId = doc.data()?.userId;
			if (typeof matchId === 'string') {
				await processFinishedMatchPoints(matchId);
			}
			if (typeof userId === 'string') {
				await recalculateNormalUserPoints(userId);
			}
		} else if (id.startsWith('worldCup:')) {
			const parts = id.split(':');
			const uid = parts[1];
			const matchId = parts.slice(2).join(':');
			const ref = db.collection('world_cup_predictions').doc(uid);
			const doc = await ref.get();
			const picks = {
				...((doc.data()?.matchPredictions as
					| Record<string, Record<string, unknown>>
					| undefined) ?? {}),
			};
			picks[matchId] = {
				...(picks[matchId] ?? {}),
				homeGuess,
				awayGuess,
			};
			await ref.set(
				{
					matchPredictions: picks,
					updatedAt: admin.firestore.FieldValue.serverTimestamp(),
				},
				{ merge: true },
			);
			await recalculateWorldCupUserScore(uid);
		} else {
			throw new functions.https.HttpsError(
				'invalid-argument',
				'Tipo de prediccion invalido',
			);
		}
		return { success: true };
	},
);

export const adminUpdateUserPoints = functions.https.onCall(
	async (data, context) => {
		requireAdmin(context);
		const userId = optionalString(data.userId);
		const mode = optionalString(data.mode);
		const operation = optionalString(data.operation);
		const value = data.value;
		if (!userId || !['normal', 'worldCup'].includes(mode)) {
			throw new functions.https.HttpsError(
				'invalid-argument',
				'Usuario o modo invalido',
			);
		}
		if (!Number.isInteger(value) || Math.abs(value as number) > 1000000) {
			throw new functions.https.HttpsError(
				'invalid-argument',
				'Puntaje invalido',
			);
		}
		const field = 'totalPoints';
		const ref =
			mode === 'worldCup'
				? admin.firestore().collection('world_cup_scores').doc(userId)
				: admin.firestore().collection('users').doc(userId);
		await ref.set(
			{
				[field]:
					operation === 'adjust'
						? admin.firestore.FieldValue.increment(value as number)
						: value,
				updatedAt: admin.firestore.FieldValue.serverTimestamp(),
			},
			{ merge: true },
		);
		return { success: true };
	},
);

export const adminUpdatePredictionPermissions = functions.https.onCall(
	async (data, context) => {
		requireAdmin(context);
		const userId = optionalString(data.userId);
		if (!userId) {
			throw new functions.https.HttpsError(
				'invalid-argument',
				'Usuario invalido',
			);
		}
		await admin.firestore().collection('users').doc(userId).set(
			{
				predictionPermissions: {
					blocked: data.blocked === true,
					bypassLocks: data.bypassLocks === true,
				},
				updatedAt: admin.firestore.FieldValue.serverTimestamp(),
			},
			{ merge: true },
		);
		return { success: true };
	},
);
