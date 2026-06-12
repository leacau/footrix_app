import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

export const validatePredictionEdit = functions.https.onCall(
	async (data, context) => {
		if (!context.auth) {
			throw new functions.https.HttpsError('unauthenticated', 'No autenticado');
		}

		const { matchId, homeGuess, awayGuess } = data;
		const uid = context.auth.uid;
		const userDoc = await admin.firestore().collection('users').doc(uid).get();
		const permissions = userDoc.data()?.predictionPermissions;
		if (permissions?.blocked === true) {
			throw new functions.https.HttpsError(
				'permission-denied',
				'Tu usuario no tiene habilitadas las predicciones',
			);
		}
		const bypassLocks = permissions?.bypassLocks === true;

		if (typeof matchId !== 'string' || matchId.trim().length === 0) {
			throw new functions.https.HttpsError(
				'invalid-argument',
				'Partido invalido',
			);
		}

		if (!Number.isInteger(homeGuess) || !Number.isInteger(awayGuess)) {
			throw new functions.https.HttpsError(
				'invalid-argument',
				'Los goles deben ser numeros enteros',
			);
		}

		if (homeGuess < 0 || awayGuess < 0 || homeGuess > 30 || awayGuess > 30) {
			throw new functions.https.HttpsError(
				'invalid-argument',
				'Resultado fuera de rango',
			);
		}

		const cleanMatchId = matchId.trim();
		const matchDoc = await admin
			.firestore()
			.collection('matches')
			.doc(cleanMatchId)
			.get();

		if (!matchDoc.exists) {
			throw new functions.https.HttpsError(
				'not-found',
				'Partido no encontrado',
			);
		}

		const match = matchDoc.data()!;
		if (!bypassLocks && match.status !== 'scheduled') {
			throw new functions.https.HttpsError(
				'failed-precondition',
				'El partido ya no acepta predicciones',
			);
		}

		const kickoff = match.kickoff as admin.firestore.Timestamp | undefined;
		if (!bypassLocks && !kickoff) {
			throw new functions.https.HttpsError(
				'failed-precondition',
				'El partido todavia no tiene fecha confirmada',
			);
		}

		const kickoffTime = kickoff?.toMillis() ?? Date.now();
		const settingsDoc = await admin
			.firestore()
			.collection('app_config')
			.doc('predictions')
			.get();
		const settingsLockHours = settingsDoc.data()?.lockHoursBefore;
		const lockHours =
			typeof settingsLockHours === 'number'
				? settingsLockHours
				: typeof match.lockHoursBefore === 'number'
					? match.lockHoursBefore
					: 12;
		const lockTime = kickoffTime - lockHours * 60 * 60 * 1000;

		if (!bypassLocks && Date.now() >= lockTime) {
			throw new functions.https.HttpsError(
				'failed-precondition',
				`Cerrado ${lockHours}hs antes`,
			);
		}

		const predictionId = `${uid}_${cleanMatchId}`;
		await admin.firestore().collection('predictions').doc(predictionId).set(
			{
				userId: uid,
				matchId: cleanMatchId,
				homeGuess,
				awayGuess,
				status: 'pending',
				submittedAt: admin.firestore.FieldValue.serverTimestamp(),
				kickoffTime,
				lockHoursBefore: lockHours,
			},
			{ merge: true },
		);

		return { success: true };
	},
);
