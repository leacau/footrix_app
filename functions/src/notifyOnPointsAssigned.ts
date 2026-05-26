import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { sendNotificationToUser } from './sendUserNotification';

export const notifyOnPointsAssigned = functions.firestore
	.document('predictions/{predictionId}')
	.onUpdate(async (change) => {
		const before = change.before.data();
		const after = change.after.data();

		if (before.status === 'graded' || after.status !== 'graded') {
			return null;
		}

		const userId = after.userId as string;
		const matchId = after.matchId as string;
		const points = (after.pointsEarned as number) ?? 0;

		const matchDoc = await admin
			.firestore()
			.collection('matches')
			.doc(matchId)
			.get();

		if (!matchDoc.exists) {
			console.log(`Match ${matchId} not found for points notification`);
			return null;
		}

		const match = matchDoc.data()!;
		const homeTeam = match.homeTeam as string;
		const awayTeam = match.awayTeam as string;
		const homeScore = match.homeScore ?? 0;
		const awayScore = match.awayScore ?? 0;

		let title: string;
		let body: string;

		if (points >= 3) {
			title = 'Punteria perfecta';
			body = `Ganaste ${points} pts en ${homeTeam} ${homeScore} - ${awayScore} ${awayTeam}`;
		} else if (points === 1) {
			title = 'Bien hecho';
			body = `Ganaste ${points} pt en ${homeTeam} ${homeScore} - ${awayScore} ${awayTeam}`;
		} else {
			title = 'Esta vez no';
			body = `No ganaste puntos en ${homeTeam} ${homeScore} - ${awayScore} ${awayTeam}`;
		}

		const result = await sendNotificationToUser(userId, {
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
		});

		console.log(
			`Points push sent to ${userId} via ${result.target}: ok=${result.successCount}, failed=${result.failureCount}`,
		);

		return null;
	});
