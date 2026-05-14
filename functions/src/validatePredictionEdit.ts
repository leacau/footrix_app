import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

export const validatePredictionEdit = functions.https.onCall(
	async (data, context) => {
		if (!context.auth) {
			throw new functions.https.HttpsError('unauthenticated', 'No autenticado');
		}

		const { matchId, homeGuess, awayGuess } = data;
		const uid = context.auth.uid;

		// Obtener partido para validar 12hs
		const matchDoc = await admin
			.firestore()
			.collection('matches')
			.doc(matchId)
			.get();
		if (!matchDoc.exists) {
			throw new functions.https.HttpsError(
				'not-found',
				'Partido no encontrado',
			);
		}

		const match = matchDoc.data()!;
		const kickoffTime = (match.kickoff as admin.firestore.Timestamp).toMillis();
		const now = Date.now();

		// Validar 12hs antes (server time)
		if (now > kickoffTime - 12 * 60 * 60 * 1000) {
			throw new functions.https.HttpsError(
				'failed-precondition',
				'Cerrado 12hs antes',
			);
		}

		// Guardar predicción
		const predictionId = `${uid}_${matchId}`;
		await admin.firestore().collection('predictions').doc(predictionId).set(
			{
				userId: uid,
				matchId,
				homeGuess,
				awayGuess,
				status: 'pending',
				submittedAt: admin.firestore.FieldValue.serverTimestamp(),
				kickoffTime,
			},
			{ merge: true },
		);

		return { success: true };
	},
);
