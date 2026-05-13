import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

admin.initializeApp();

/**
 * 🔥 Calcula puntos al finalizar un partido
 * Reglas simplificadas:
 * - 3 pts: Resultado exacto
 * - 1 pt: Acertar ganador/empate (pero no el score exacto)
 */
export const calculatePointsOnMatchFinish = functions.firestore
	.document('matches/{matchId}')
	.onUpdate(async (change, context) => {
		const before = change.before.data();
		const after = change.after.data();

		// Solo ejecutar si el partido acaba de finalizar
		if (before.status !== 'finished' && after.status === 'finished') {
			const db = admin.firestore();

			// Obtener predicciones pendientes de este partido
			const predictionsSnap = await db
				.collection('predictions')
				.where('matchId', '==', context.params.matchId)
				.where('status', '==', 'pending')
				.get();

			if (predictionsSnap.empty) {
				console.log(
					`ℹ️ No hay predicciones pendientes para ${context.params.matchId}`,
				);
				return null;
			}

			const batch = db.batch();
			let updatedCount = 0;

			// ✅ CORRECCIÓN: Usar for...of en lugar de forEach para soportar await
			for (const doc of predictionsSnap.docs) {
				const p = doc.data();
				let pts = 0;

				// Valores seguros con fallback a 0
				const homeGuess = (p.homeGuess as number) || 0;
				const awayGuess = (p.awayGuess as number) || 0;
				const homeScore = (after.homeScore as number) || 0;
				const awayScore = (after.awayScore as number) || 0;

				// 🎯 3 pts: Resultado EXACTO
				if (homeGuess === homeScore && awayGuess === awayScore) {
					pts = 3;
				}
				// 🎯 1 pt: Acertar el RESULTADO (ganador/empate)
				else if (
					// Local gana en ambos
					(homeGuess > awayGuess && homeScore > awayScore) ||
					// Visita gana en ambos
					(homeGuess < awayGuess && homeScore < awayScore) ||
					// Empate en ambos
					(homeGuess === awayGuess && homeScore === awayScore)
				) {
					pts = 1;
				}

				// Actualizar predicción
				batch.update(doc.ref, {
					pointsEarned: pts,
					status: 'graded',
					gradedAt: admin.firestore.FieldValue.serverTimestamp(),
				});

				// Sumar puntos al usuario
				const userRef = db.collection('users').doc(p.userId as string);

				// ✅ CORRECCIÓN: await dentro de for...of (sí funciona)
				const userDoc = await userRef.get();

				if (userDoc.exists) {
					batch.update(userRef, {
						totalPoints: admin.firestore.FieldValue.increment(pts),
						updatedAt: admin.firestore.FieldValue.serverTimestamp(),
					});
				} else {
					// Fallback: crear usuario si no existe (por seguridad)
					batch.set(
						userRef,
						{
							uid: p.userId,
							totalPoints: pts,
							createdAt: admin.firestore.FieldValue.serverTimestamp(),
							updatedAt: admin.firestore.FieldValue.serverTimestamp(),
						},
						{ merge: true },
					);
				}

				updatedCount++;
			}

			await batch.commit();
			console.log(
				`✅ ${updatedCount} predicciones procesadas para ${context.params.matchId}`,
			);
			return { success: true, updatedCount };
		}

		return null;
	});

export const validatePredictionEdit = functions.https.onCall(
	async (data, context) => {
		if (!context.auth)
			throw new functions.https.HttpsError('unauthenticated', 'No autenticado');

		const { matchId, homeGuess, awayGuess } = data;
		const uid = context.auth.uid;

		// Obtener partido
		const matchDoc = await admin
			.firestore()
			.collection('matches')
			.doc(matchId)
			.get();
		if (!matchDoc.exists)
			throw new functions.https.HttpsError(
				'not-found',
				'Partido no encontrado',
			);

		const match = matchDoc.data()!;
		const kickoffTime = (match.kickoff as admin.firestore.Timestamp).toMillis();
		const now = Date.now();

		// 🔒 Validar 12hs antes usando server time
		if (now > kickoffTime - 12 * 60 * 60 * 1000) {
			throw new functions.https.HttpsError(
				'failed-precondition',
				'Las predicciones se cierran 12hs antes del partido',
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

