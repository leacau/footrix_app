import * as admin from 'firebase-admin';

type UserNotificationPayload = Omit<
	admin.messaging.MulticastMessage,
	'tokens'
>;

const DEAD_TOKEN_CODES = new Set([
	'messaging/invalid-registration-token',
	'messaging/registration-token-not-registered',
	'messaging/invalid-argument',
]);

function chunk<T>(items: T[], size: number): T[][] {
	const chunks: T[][] = [];
	for (let index = 0; index < items.length; index += size) {
		chunks.push(items.slice(index, index + size));
	}
	return chunks;
}

async function getUserTokenEntries(userId: string): Promise<
	Array<{
		token: string;
		ref?: admin.firestore.DocumentReference;
	}>
> {
	const db = admin.firestore();
	const entries = new Map<
		string,
		{ token: string; ref?: admin.firestore.DocumentReference }
	>();

	const legacyDoc = await db.collection('user_tokens').doc(userId).get();
	const legacyToken = legacyDoc.data()?.token;
	if (typeof legacyToken === 'string' && legacyToken.trim()) {
		entries.set(legacyToken, { token: legacyToken });
	}

	const tokensSnap = await db
		.collection('user_tokens')
		.doc(userId)
		.collection('tokens')
		.get();

	for (const doc of tokensSnap.docs) {
		const token = doc.data().token;
		if (typeof token === 'string' && token.trim()) {
			entries.set(token, { token, ref: doc.ref });
		}
	}

	return [...entries.values()];
}

export async function sendNotificationToUser(
	userId: string,
	payload: UserNotificationPayload,
): Promise<{ successCount: number; failureCount: number; target: string }> {
	const entries = await getUserTokenEntries(userId);

	if (entries.length === 0) {
		await admin.messaging().send({
			topic: `user_${userId}`,
			...payload,
		});
		return { successCount: 1, failureCount: 0, target: 'topic' };
	}

	let successCount = 0;
	let failureCount = 0;
	const entryByToken = new Map(entries.map((entry) => [entry.token, entry]));

	for (const tokenChunk of chunk(entries.map((entry) => entry.token), 500)) {
		const response = await admin.messaging().sendEachForMulticast({
			tokens: tokenChunk,
			...payload,
		});
		successCount += response.successCount;
		failureCount += response.failureCount;

		const cleanupPromises = response.responses
			.map((result, index) => ({ result, token: tokenChunk[index] }))
			.filter(({ result }) => {
				const code = result.error?.code;
				return code != null && DEAD_TOKEN_CODES.has(code);
			})
			.map(({ token }) => entryByToken.get(token)?.ref?.delete());

		await Promise.all(cleanupPromises);
	}

	return { successCount, failureCount, target: 'tokens' };
}
