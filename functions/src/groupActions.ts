import { randomInt } from 'crypto';
import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

const GROUP_CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

function requireAuth(context: functions.https.CallableContext): string {
	if (!context.auth) {
		throw new functions.https.HttpsError('unauthenticated', 'No autenticado');
	}
	return context.auth.uid;
}

function normalizeCode(code: unknown): string {
	const normalized = typeof code === 'string' ? code.trim().toUpperCase() : '';
	if (!/^[A-HJ-NP-Z2-9]{6}$/.test(normalized)) {
		throw new functions.https.HttpsError(
			'invalid-argument',
			'Codigo invalido',
		);
	}
	return normalized;
}

function generateGroupCode(): string {
	let code = '';
	for (let i = 0; i < 6; i++) {
		code += GROUP_CODE_CHARS[randomInt(GROUP_CODE_CHARS.length)];
	}
	return code;
}

export const createGroup = functions.https.onCall(async (data, context) => {
	const uid = requireAuth(context);
	const name = typeof data.name === 'string' ? data.name.trim() : '';
	const leagueId = typeof data.leagueId === 'string' ? data.leagueId.trim() : '';
	const isLeagueExclusive = data.isLeagueExclusive === true;

	if (name.length < 3 || name.length > 40) {
		throw new functions.https.HttpsError(
			'invalid-argument',
			'El nombre debe tener entre 3 y 40 caracteres',
		);
	}

	if (!leagueId) {
		throw new functions.https.HttpsError(
			'invalid-argument',
			'Selecciona una liga',
		);
	}

	const db = admin.firestore();
	const leagueDoc = await db.collection('leagues').doc(leagueId).get();
	if (!leagueDoc.exists || leagueDoc.data()?.active !== true) {
		throw new functions.https.HttpsError('not-found', 'Liga no encontrada');
	}

	let code = generateGroupCode();
	let groupRef = db.collection('groups').doc(code);
	for (let attempt = 0; attempt < 5 && (await groupRef.get()).exists; attempt++) {
		code = generateGroupCode();
		groupRef = db.collection('groups').doc(code);
	}

	if ((await groupRef.get()).exists) {
		throw new functions.https.HttpsError(
			'aborted',
			'No se pudo generar un codigo unico',
		);
	}

	const league = leagueDoc.data()!;
	await groupRef.set({
		groupId: code,
		name,
		code,
		createdBy: uid,
		members: [uid],
		leagueId,
		leagueName: league.name ?? null,
		isLeagueExclusive,
		createdAt: admin.firestore.FieldValue.serverTimestamp(),
		updatedAt: admin.firestore.FieldValue.serverTimestamp(),
	});

	return { success: true, code };
});

export const joinGroup = functions.https.onCall(async (data, context) => {
	const uid = requireAuth(context);
	const code = normalizeCode(data.code);
	const groupRef = admin.firestore().collection('groups').doc(code);

	await admin.firestore().runTransaction(async (tx) => {
		const groupDoc = await tx.get(groupRef);
		if (!groupDoc.exists) {
			throw new functions.https.HttpsError('not-found', 'Codigo invalido');
		}

		const group = groupDoc.data()!;
		const members = Array.isArray(group.members)
			? (group.members as string[])
			: [];
		if (members.includes(uid)) {
			throw new functions.https.HttpsError(
				'already-exists',
				'Ya sos miembro de este grupo',
			);
		}

		tx.update(groupRef, {
			members: admin.firestore.FieldValue.arrayUnion(uid),
			updatedAt: admin.firestore.FieldValue.serverTimestamp(),
		});
	});

	return { success: true };
});
