import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

export const notifyOnGroupInvite = functions.firestore
	.document('groups/{groupId}')
	.onUpdate(async (change, context) => {
		const before = change.before.data();
		const after = change.after.data();

		const beforeMembers = (before.members as string[]) || [];
		const afterMembers = (after.members as string[]) || [];

		// Encontrar nuevos miembros (los que están en after pero no en before)
		const newMembers = afterMembers.filter(
			(uid) => !beforeMembers.includes(uid),
		);

		if (newMembers.length === 0) {
			return null; // No hay nuevos invitados
		}

		const groupName = after.name as string;
		const groupId = context.params.groupId;

		for (const userId of newMembers) {
			// Obtener token del usuario invitado
			const userDoc = await admin
				.firestore()
				.collection('users')
				.doc(userId)
				.get();

			const fcmToken = userDoc.data()?.fcmToken as string | undefined;
			const displayName = (userDoc.data()?.displayName as string) || 'Amigo';

			const title = '👥 ¡Te invitaron!';
			const body = `${displayName} te agregó al grupo "${groupName}"`;

			if (fcmToken) {
				await admin.messaging().send({
					token: fcmToken,
					notification: { title, body },
					data: {
						route: '/groups',
						type: 'group_invite',
						groupId,
					},
					android: {
						notification: {
							channelId: 'footrix_channel',
							sound: 'default',
						},
					},
					apns: {
						payload: {
							aps: {
								sound: 'default',
							},
						},
					},
				});
				console.log(`✅ Invite push enviado a ${userId}`);
			} else {
				// Fallback a topic
				await admin.messaging().send({
					topic: `user_${userId}`,
					notification: { title, body },
					data: {
						route: '/groups',
						type: 'group_invite',
					},
				});
				console.log(`✅ Invite push enviado a topic user_${userId}`);
			}
		}

		return null;
	});
