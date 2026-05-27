import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

function requireAuth(context: functions.https.CallableContext): void {
	if (!context.auth) {
		throw new functions.https.HttpsError('unauthenticated', 'No autenticado');
	}
}

function chunk<T>(items: T[], size: number): T[][] {
	const chunks: T[][] = [];
	for (let index = 0; index < items.length; index += size) {
		chunks.push(items.slice(index, index + size));
	}
	return chunks;
}

export const getRankingPredictionCounts = functions.https.onCall(
	async (data, context) => {
		requireAuth(context);
		const rawUserIds: unknown[] = Array.isArray(data.userIds)
			? data.userIds
			: [];
		const rawLeagueIds: unknown[] = Array.isArray(data.leagueIds)
			? data.leagueIds
			: [];
		const userIds = rawUserIds.length > 0
			? [
					...new Set(
						rawUserIds
							.filter((value): value is string => typeof value === 'string')
							.map((value) => value.trim())
							.filter((value) => value.length > 0),
					),
				].slice(0, 250)
			: [];
		const leagueIds = rawLeagueIds.length > 0
			? [
					...new Set(
						rawLeagueIds
							.filter((value): value is string => typeof value === 'string')
							.map((value) => value.trim())
							.filter((value) => value.length > 0),
					),
				]
			: [];

		if (userIds.length === 0) return { counts: {} };

		const db = admin.firestore();
		const counts: Record<string, number> = {};

		for (const userChunk of chunk(userIds, 30)) {
			const predictionsSnap = await db
				.collection('predictions')
				.where('userId', 'in', userChunk)
				.get();

			if (leagueIds.length === 0) {
				for (const doc of predictionsSnap.docs) {
					const userId = doc.data().userId;
					if (typeof userId === 'string') {
						counts[userId] = (counts[userId] ?? 0) + 1;
					}
				}
				continue;
			}

			const matchIds = [
				...new Set(
					predictionsSnap.docs
						.map((doc) => doc.data().matchId)
						.filter((value): value is string => typeof value === 'string'),
				),
			];
			const matchLeagueIds = new Map<string, string>();
			for (const matchChunk of chunk(matchIds, 30)) {
				const matchDocs = await db.getAll(
					...matchChunk.map((matchId) => db.collection('matches').doc(matchId)),
				);
				for (const matchDoc of matchDocs) {
					const leagueId = matchDoc.data()?.leagueId;
					if (typeof leagueId === 'string') {
						matchLeagueIds.set(matchDoc.id, leagueId);
					}
				}
			}

			for (const doc of predictionsSnap.docs) {
				const prediction = doc.data();
				const userId = prediction.userId;
				const matchId = prediction.matchId;
				const leagueId =
					typeof matchId === 'string' ? matchLeagueIds.get(matchId) : null;
				if (
					typeof userId === 'string' &&
					typeof leagueId === 'string' &&
					leagueIds.includes(leagueId)
				) {
					counts[userId] = (counts[userId] ?? 0) + 1;
				}
			}
		}

		return { counts };
	},
);
