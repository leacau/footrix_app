import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

export const notifyOnPointsAssigned = functions.firestore
	.document('predictions/{predictionId}')
	.onUpdate(async (change, context) => {
		const before = change.before.data();
		const after = change.after.data();

		// Solo actuar si la predicción acaba de ser "graded"
		if (before.status !== 'graded' && after.status === 'graded') {
			const userId = after.userId as string;
			const matchId = after.matchId as string;
			const points = (after.pointsEarned as number) ?? 0;

			// Obtener datos del partido
			const matchDoc = await admin
				.firestore()
				.collection('matches')
				.doc(matchId)
				.get();

			if (!matchDoc.exists) {
				console.log(`⚠️ Partido ${matchId} no encontrado`);
				return null;
			}

			const match = matchDoc.data()!;
			const homeTeam = match.homeTeam as string;
			const awayTeam = match.awayTeam as string;
			const homeScore = match.homeScore ?? 0;
			const awayScore = match.awayScore ?? 0;

			// ✅ Lógica de título y cuerpo CORREGIDA
			let title: string;
			let body: string;

			if (points >= 3) {
				title = '🎯 ¡Puntería!';
				body = `Ganaste ${points} pts en ${homeTeam} ${homeScore} - ${awayScore} ${awayTeam}`;
			} else if (points === 1) {
				title = '✅ ¡Bien hecho!';
				body = `Ganaste ${points} pt en ${homeTeam} ${homeScore} - ${awayScore} ${awayTeam}`;
			} else {
				// points === 0
				title = '❌ ¡Esta vez no!';
				body = `No ganaste puntos en ${homeTeam} ${homeScore} - ${awayScore} ${awayTeam}`;
			}

			// Log para debug
			console.log(
				`🔔 Notificación para ${userId}: title="${title}", body="${body}", points=${points}`,
			);

			// Obtener token del usuario
			const userDoc = await admin
				.firestore()
				.collection('users')
				.doc(userId)
				.get();

			const fcmToken = userDoc.data()?.fcmToken as string | undefined;

			const payload = {
				notification: { title, body },
				data: {
					route: `/match/${matchId}`,
					type: 'points_assigned',
					points: points.toString(),
				},
				android: {
					notification: {
						channelId: 'footrix_channel',
						sound: 'default',
					},
				},
				apns: {
					payload: {
						aps: { sound: 'default' },
					},
				},
			};

			if (fcmToken) {
				await admin.messaging().send({ token: fcmToken, ...payload });
				console.log(`✅ Push enviado a token de ${userId}`);
			} else {
				await admin.messaging().send({ topic: `user_${userId}`, ...payload });
				console.log(`✅ Push enviado a topic user_${userId}`);
			}
		}

		return null;
	});
