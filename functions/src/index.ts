import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

admin.initializeApp();

/**
 * 🔥 Se ejecuta AUTOMÁTICAMENTE cuando un partido cambia a "finished"
 * Calcula puntos y actualiza rankings en tiempo real.
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

			predictionsSnap.forEach((doc) => {
				const p = doc.data();
				let pts = 0;

				// Valores seguros con fallback a 0
				const homeGuess = (p.homeGuess as number) || 0;
				const awayGuess = (p.awayGuess as number) || 0;
				const homeScore = (after.homeScore as number) || 0;
				const awayScore = (after.awayScore as number) || 0;

				// 🎯 3 pts: resultado exacto
				if (homeGuess === homeScore && awayGuess === awayScore) {
					pts = 3;
				}
				// 🎯 1 pt: acertar ganador/empate
				else if (
					(homeGuess > awayGuess && homeScore > awayScore) ||
					(homeGuess < awayGuess && homeScore < awayScore) ||
					(homeGuess === awayGuess && homeScore === awayScore)
				) {
					pts = 1;
				}

				// 🎯 1 pt extra: goles totales (±1 tolerancia)
				const totalGuess =
					(p.totalGoalsGuess as number) || homeGuess + awayGuess;
				const totalReal = homeScore + awayScore;
				if (Math.abs(totalGuess - totalReal) <= 1) {
					pts += 1;
				}

				// 🎯 1 pt extra: acertar si hay penales
				if (p.penaltiesGuess === after.hasPenalties) {
					pts += 1;
				}

				// Actualizar predicción
				batch.update(doc.ref, {
					pointsEarned: pts,
					status: 'graded',
					gradedAt: admin.firestore.FieldValue.serverTimestamp(),
				});

				// Sumar puntos al usuario
				const userRef = db.collection('users').doc(p.userId as string);
				batch.update(userRef, {
					totalPoints: admin.firestore.FieldValue.increment(pts),
					updatedAt: admin.firestore.FieldValue.serverTimestamp(),
				});

				updatedCount++;
			});

			await batch.commit();
			console.log(
				`✅ ${updatedCount} predicciones procesadas para ${context.params.matchId}`,
			);
			return { success: true, updatedCount };
		}

		return null;
	});
