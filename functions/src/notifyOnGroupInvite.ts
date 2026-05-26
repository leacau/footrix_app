import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { sendNotificationToUser } from './sendUserNotification';

export const notifyOnGroupInvite = functions.firestore
	.document('groups/{groupId}')
	.onUpdate(async (change, context) => {
		const before = change.before.data();
		const after = change.after.data();

		const beforeMembers = (before.members as string[]) || [];
		const afterMembers = (after.members as string[]) || [];
		const newMembers = afterMembers.filter(
			(uid) => !beforeMembers.includes(uid),
		);

		if (newMembers.length === 0) {
			return null;
		}

		const groupName = (after.name as string) || 'Footrix';
		const groupId = context.params.groupId;

		for (const userId of newMembers) {
			const userDoc = await admin
				.firestore()
				.collection('users')
				.doc(userId)
				.get();

			const displayName = (userDoc.data()?.displayName as string) || 'Alguien';
			const result = await sendNotificationToUser(userId, {
				notification: {
					title: 'Te invitaron a un grupo',
					body: `${displayName} te agrego a "${groupName}"`,
				},
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
						aps: { sound: 'default' },
					},
				},
			});

			console.log(
				`Invite push sent to ${userId} via ${result.target}: ok=${result.successCount}, failed=${result.failureCount}`,
			);
		}

		return null;
	});
