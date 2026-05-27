import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { sendNotificationToUser } from './sendUserNotification';

function isAnonymousProfile(user: admin.firestore.DocumentData): boolean {
	const displayName =
		typeof user.displayName === 'string'
			? user.displayName.trim().toLowerCase()
			: '';
	return (
		displayName.length === 0 ||
		displayName === 'anonimo' ||
		displayName === 'anónimo' ||
		displayName === 'anonymous' ||
		displayName === 'usuario' ||
		displayName === 'user'
	);
}

export const remindAnonymousUsersToCompleteProfile = functions.pubsub
	.schedule('every monday 10:00')
	.timeZone('America/Argentina/Buenos_Aires')
	.onRun(async () => {
		const usersSnap = await admin.firestore().collection('users').get();
		let sent = 0;

		for (const userDoc of usersSnap.docs) {
			const user = userDoc.data();
			if (!isAnonymousProfile(user)) continue;

			await sendNotificationToUser(userDoc.id, {
				notification: {
					title: 'Completa tu perfil en Footrix',
					body: 'Sumá tu nombre de usuario, país y datos para que tus grupos te reconozcan.',
				},
				data: {
					route: '/profile',
					type: 'profile_reminder',
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
			sent++;
		}

		console.log(`Profile reminders sent: ${sent}`);
		return null;
	});
