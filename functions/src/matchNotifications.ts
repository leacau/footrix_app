import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

import { sendNotificationToUser } from './sendUserNotification';

type MatchEvent = 'one_hour' | 'ten_minutes' | 'started';

function text(value: unknown, fallback: string): string {
	return typeof value === 'string' && value.trim() ? value.trim() : fallback;
}

async function reserveNotification(
	userId: string,
	matchId: string,
	event: string,
): Promise<admin.firestore.DocumentReference | null> {
	const ref = admin
		.firestore()
		.collection('notification_events')
		.doc(`${userId}_${matchId}_${event}`);
	try {
		await ref.create({
			userId,
			matchId,
			event,
			createdAt: admin.firestore.FieldValue.serverTimestamp(),
		});
		return ref;
	} catch (error) {
		const code = (error as { code?: number | string }).code;
		if (code === 6 || code === 'already-exists') return null;
		throw error;
	}
}

async function userHasPrediction(userId: string, matchId: string): Promise<boolean> {
	const deterministic = await admin
		.firestore()
		.collection('predictions')
		.doc(`${userId}_${matchId}`)
		.get();
	if (deterministic.exists) return true;
	const fallback = await admin
		.firestore()
		.collection('predictions')
		.where('userId', '==', userId)
		.where('matchId', '==', matchId)
		.limit(1)
		.get();
	return !fallback.empty;
}

function reminderCopy(
	event: MatchEvent,
	home: string,
	away: string,
	hasPrediction: boolean,
): { title: string; body: string } {
	if (event === 'started') {
		return hasPrediction
			? {
					title: 'Ya comenzó el partido',
					body: `${home} vs ${away}: seguí el resultado de tu predicción.`,
				}
			: {
					title: 'Ya comenzó el partido',
					body: `${home} vs ${away} está en juego.`,
				};
	}
	const time = event === 'one_hour' ? 'una hora' : '10 minutos';
	return hasPrediction
		? {
				title: 'Tu predicción juega pronto',
				body: `${home} vs ${away} comienza en ${time}. Atento al resultado.`,
			}
		: {
				title: 'Te falta una predicción',
				body: `${home} vs ${away} comienza en ${time}. Todavía estás a tiempo.`,
			};
}

async function notifyLeagueUsers(
	matchDoc: admin.firestore.QueryDocumentSnapshot | admin.firestore.DocumentSnapshot,
	event: MatchEvent,
): Promise<number> {
	const match = matchDoc.data();
	if (!match) return 0;
	const leagueId = match.leagueId;
	if (typeof leagueId !== 'string' || !leagueId) return 0;

	const users = await admin
		.firestore()
		.collection('users')
		.where('selectedLeagueIds', 'array-contains', leagueId)
		.get();
	let sent = 0;
	for (const userDoc of users.docs) {
		const reservation = await reserveNotification(userDoc.id, matchDoc.id, event);
		if (!reservation) continue;
		try {
			const hasPrediction = await userHasPrediction(userDoc.id, matchDoc.id);
			const copy = reminderCopy(
				event,
				text(match.homeTeam, 'Local'),
				text(match.awayTeam, 'Visitante'),
				hasPrediction,
			);
			await sendNotificationToUser(userDoc.id, {
				notification: copy,
				data: {
					route: `/fixture?matchId=${matchDoc.id}`,
					type: event,
					matchId: matchDoc.id,
				},
				android: {
					notification: { channelId: 'footrix_channel', sound: 'default' },
				},
				apns: { payload: { aps: { sound: 'default' } } },
			});
			sent++;
		} catch (error) {
			await reservation.delete();
			throw error;
		}
	}
	return sent;
}

export const sendUpcomingMatchReminders = functions.pubsub
	.schedule('every 5 minutes')
	.timeZone('America/Argentina/Buenos_Aires')
	.onRun(async () => {
		const now = Date.now();
		const from = admin.firestore.Timestamp.fromMillis(now - 15 * 60 * 1000);
		const to = admin.firestore.Timestamp.fromMillis(now + 65 * 60 * 1000);
		const matches = await admin
			.firestore()
			.collection('matches')
			.where('kickoff', '>=', from)
			.where('kickoff', '<=', to)
			.get();

		let sent = 0;
		for (const matchDoc of matches.docs) {
			const match = matchDoc.data();
			if (match.status === 'finished') continue;
			const kickoff = match.kickoff as admin.firestore.Timestamp | undefined;
			if (!kickoff) continue;
			const minutes = (kickoff.toMillis() - now) / 60000;
			let event: MatchEvent | null = null;
			if (minutes > 55 && minutes <= 65) event = 'one_hour';
			else if (minutes > 5 && minutes <= 15) event = 'ten_minutes';
			else if (
				minutes > -15 &&
				minutes <= 1 &&
				match.status === 'live'
			) {
				event = 'started';
			}
			if (event) sent += await notifyLeagueUsers(matchDoc, event);
		}
		console.log(`Upcoming match reminders sent: ${sent}`);
		return null;
	});

export const notifyOnMatchGoal = functions.firestore
	.document('matches/{matchId}')
	.onUpdate(async (change, context) => {
		const before = change.before.data();
		const after = change.after.data();
		if (after.status !== 'live') return null;
		const beforeHome = typeof before.homeScore === 'number' ? before.homeScore : 0;
		const beforeAway = typeof before.awayScore === 'number' ? before.awayScore : 0;
		const home = typeof after.homeScore === 'number' ? after.homeScore : 0;
		const away = typeof after.awayScore === 'number' ? after.awayScore : 0;
		if (home + away <= beforeHome + beforeAway) return null;

		const leagueId = after.leagueId;
		if (typeof leagueId !== 'string' || !leagueId) return null;
		const users = await admin
			.firestore()
			.collection('users')
			.where('selectedLeagueIds', 'array-contains', leagueId)
			.get();
		let sent = 0;
		for (const userDoc of users.docs) {
			const event = `goal_${home}_${away}`;
			const reservation = await reserveNotification(
				userDoc.id,
				context.params.matchId,
				event,
			);
			if (!reservation) continue;
			try {
				await sendNotificationToUser(userDoc.id, {
					notification: {
						title: 'Gol',
						body: `${text(after.homeTeam, 'Local')} ${home} - ${away} ${text(after.awayTeam, 'Visitante')}`,
					},
					data: {
						route: `/fixture?matchId=${context.params.matchId}`,
						type: 'goal',
						matchId: context.params.matchId,
					},
					android: {
						notification: { channelId: 'footrix_channel', sound: 'default' },
					},
					apns: { payload: { aps: { sound: 'default' } } },
				});
				sent++;
			} catch (error) {
				await reservation.delete();
				throw error;
			}
		}
		console.log(`Goal notifications sent for ${context.params.matchId}: ${sent}`);
		return null;
	});
