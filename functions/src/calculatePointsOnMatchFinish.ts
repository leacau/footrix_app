import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

function predictionPoints(
	homeGuess: number,
	awayGuess: number,
	homeScore: number,
	awayScore: number,
): number {
	if (homeGuess === homeScore && awayGuess === awayScore) return 3;
	if (
		(homeGuess > awayGuess && homeScore > awayScore) ||
		(homeGuess < awayGuess && homeScore < awayScore) ||
		(homeGuess === awayGuess && homeScore === awayScore)
	) {
		return 1;
	}
	return 0;
}

export async function processFinishedMatchPoints(
	matchId: string,
): Promise<{ updatedCount: number; totalDelta: number }> {
	const db = admin.firestore();
	const matchDoc = await db.collection('matches').doc(matchId).get();
	if (!matchDoc.exists) {
		throw new Error(`Match ${matchId} not found`);
	}

	const match = matchDoc.data()!;
	if (match.status !== 'finished') {
		return { updatedCount: 0, totalDelta: 0 };
	}

	const finalHomeScore = match.homeScore;
	const finalAwayScore = match.awayScore;
	if (typeof finalHomeScore !== 'number' || typeof finalAwayScore !== 'number') {
		console.log(`Skipping points for ${matchId}: final score is incomplete`);
		return { updatedCount: 0, totalDelta: 0 };
	}

	const predictionsSnap = await db
		.collection('predictions')
		.where('matchId', '==', matchId)
		.get();

	if (predictionsSnap.empty) {
		console.log(`No predictions found for ${matchId}`);
		return { updatedCount: 0, totalDelta: 0 };
	}

	const writer = db.bulkWriter();
	let updatedCount = 0;
	let totalDelta = 0;
	const userDeltas = new Map<
		string,
		{ total: number; leagues: Map<string, number> }
	>();

	for (const doc of predictionsSnap.docs) {
		const prediction = doc.data();
		const userId = prediction.userId;
		if (typeof userId !== 'string' || userId.length === 0) continue;

		const homeGuess =
			typeof prediction.homeGuess === 'number' ? prediction.homeGuess : 0;
		const awayGuess =
			typeof prediction.awayGuess === 'number' ? prediction.awayGuess : 0;
		const newPoints = predictionPoints(
			homeGuess,
			awayGuess,
			finalHomeScore,
			finalAwayScore,
		);
		const previousPoints =
			prediction.status === 'graded' &&
			typeof prediction.pointsEarned === 'number'
				? prediction.pointsEarned
				: 0;
		const delta = newPoints - previousPoints;

		writer.update(doc.ref, {
			pointsEarned: newPoints,
			status: 'graded',
			gradedAt: admin.firestore.FieldValue.serverTimestamp(),
			pointsCalculationVersion: 2,
			suppressPointsNotification: false,
		});

		if (delta !== 0) {
			const current = userDeltas.get(userId) ?? {
				total: 0,
				leagues: new Map<string, number>(),
			};
			current.total += delta;
			if (typeof match.leagueId === 'string' && match.leagueId.length > 0) {
				current.leagues.set(
					match.leagueId,
					(current.leagues.get(match.leagueId) ?? 0) + delta,
				);
			}
			userDeltas.set(userId, current);
			totalDelta += delta;
		}

		updatedCount++;
	}

	for (const [userId, delta] of userDeltas.entries()) {
		const updateData: admin.firestore.UpdateData<admin.firestore.DocumentData> =
			{
				totalPoints: admin.firestore.FieldValue.increment(delta.total),
				updatedAt: admin.firestore.FieldValue.serverTimestamp(),
			};
		for (const [leagueId, leagueDelta] of delta.leagues.entries()) {
			updateData[`leagueStats.${leagueId}.points`] =
				admin.firestore.FieldValue.increment(leagueDelta);
		}
		writer.set(db.collection('users').doc(userId), updateData, { merge: true });
	}
	await writer.close();
	console.log(
		`Processed ${updatedCount} predictions for ${matchId}, points delta=${totalDelta}`,
	);
	return { updatedCount, totalDelta };
}

export const calculatePointsOnMatchFinish = functions.firestore
	.document('matches/{matchId}')
	.onUpdate(async (change, context) => {
		const before = change.before.data();
		const after = change.after.data();

		if (after.status !== 'finished') return null;

		const becameFinished = before.status !== 'finished';
		const scoreChanged =
			before.homeScore !== after.homeScore ||
			before.awayScore !== after.awayScore;

		if (!becameFinished && !scoreChanged) return null;

		const result = await processFinishedMatchPoints(context.params.matchId);
		return { success: true, ...result };
	});
