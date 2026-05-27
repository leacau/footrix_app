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

function readLeagueIds(data: { leagueId?: unknown; leagueIds?: unknown }): string[] {
	const rawIds = Array.isArray(data.leagueIds) ? data.leagueIds : [data.leagueId];
	return [
		...new Set(
			rawIds
				.filter((value): value is string => typeof value === 'string')
				.map((value) => value.trim())
				.filter((value) => value.length > 0),
		),
	];
}

function chunk<T>(items: T[], size: number): T[][] {
	const chunks: T[][] = [];
	for (let index = 0; index < items.length; index += size) {
		chunks.push(items.slice(index, index + size));
	}
	return chunks;
}

export const createGroup = functions.https.onCall(async (data, context) => {
	const uid = requireAuth(context);
	const name = typeof data.name === 'string' ? data.name.trim() : '';
	const leagueIds = readLeagueIds(data);
	const isLeagueExclusive = data.isLeagueExclusive === true;

	if (name.length < 3 || name.length > 40) {
		throw new functions.https.HttpsError(
			'invalid-argument',
			'El nombre debe tener entre 3 y 40 caracteres',
		);
	}

	if (leagueIds.length === 0) {
		throw new functions.https.HttpsError(
			'invalid-argument',
			'Selecciona al menos una liga',
		);
	}

	const db = admin.firestore();
	const leagueDocs = await db.getAll(
		...leagueIds.map((leagueId) => db.collection('leagues').doc(leagueId)),
	);
	if (
		leagueDocs.some(
			(leagueDoc) => !leagueDoc.exists || leagueDoc.data()?.active !== true,
		)
	) {
		throw new functions.https.HttpsError(
			'not-found',
			'Una de las ligas no existe o no esta activa',
		);
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

	const leagueNames = leagueDocs.map((leagueDoc) => {
		const league = leagueDoc.data()!;
		return (league.name as string | undefined) ?? leagueDoc.id;
	});

	await db.runTransaction(async (tx) => {
		tx.set(groupRef, {
			groupId: code,
			name,
			code,
			createdBy: uid,
			members: [uid],
			leagueId: leagueIds[0],
			leagueIds,
			leagueName: leagueNames[0] ?? null,
			leagueNames,
			isLeagueExclusive,
			createdAt: admin.firestore.FieldValue.serverTimestamp(),
			updatedAt: admin.firestore.FieldValue.serverTimestamp(),
		});

		tx.set(
			db.collection('users').doc(uid),
			{
				selectedLeagueIds: admin.firestore.FieldValue.arrayUnion(...leagueIds),
				updatedAt: admin.firestore.FieldValue.serverTimestamp(),
			},
			{ merge: true },
		);
	});

	return { success: true, code };
});

export const joinGroup = functions.https.onCall(async (data, context) => {
	const uid = requireAuth(context);
	const code = normalizeCode(data.code);
	const db = admin.firestore();
	const groupRef = db.collection('groups').doc(code);

	await db.runTransaction(async (tx) => {
		const groupDoc = await tx.get(groupRef);
		if (!groupDoc.exists) {
			throw new functions.https.HttpsError('not-found', 'Codigo invalido');
		}

		const group = groupDoc.data()!;
		const members = Array.isArray(group.members)
			? (group.members as string[])
			: [];
		const leagueIds = readLeagueIds({
			leagueId: group.leagueId,
			leagueIds: group.leagueIds,
		});
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

		if (leagueIds.length > 0) {
			tx.set(
				db.collection('users').doc(uid),
				{
					selectedLeagueIds: admin.firestore.FieldValue.arrayUnion(...leagueIds),
					updatedAt: admin.firestore.FieldValue.serverTimestamp(),
				},
				{ merge: true },
			);
		}
	});

	return { success: true };
});

export const getGroupPredictions = functions.https.onCall(
	async (data, context) => {
		const uid = requireAuth(context);
		const groupId = typeof data.groupId === 'string' ? data.groupId.trim() : '';
		if (!groupId) {
			throw new functions.https.HttpsError(
				'invalid-argument',
				'Grupo invalido',
			);
		}

		const db = admin.firestore();
		const groupDoc = await db.collection('groups').doc(groupId).get();
		if (!groupDoc.exists) {
			throw new functions.https.HttpsError('not-found', 'Grupo no encontrado');
		}

		const group = groupDoc.data()!;
		const members = Array.isArray(group.members)
			? (group.members as string[])
			: [];
		if (!members.includes(uid)) {
			throw new functions.https.HttpsError(
				'permission-denied',
				'No sos miembro de este grupo',
			);
		}

		const leagueIds = readLeagueIds({
			leagueId: group.leagueId,
			leagueIds: group.leagueIds,
		});
		const memberDocs =
			members.length > 0
				? await db.getAll(
						...members.map((memberId) =>
							db.collection('users').doc(memberId),
						),
					)
				: [];
		const displayNames = new Map<string, string>();
		memberDocs.forEach((doc, index) => {
			const displayName = doc.data()?.displayName;
			displayNames.set(
				members[index],
				typeof displayName === 'string' && displayName.trim()
					? displayName.trim()
					: 'Anonimo',
			);
		});

		const predictionDocs: admin.firestore.QueryDocumentSnapshot[] = [];
		for (const memberChunk of chunk(members, 30)) {
			const snap = await db
				.collection('predictions')
				.where('userId', 'in', memberChunk)
				.get();
			predictionDocs.push(...snap.docs);
		}

		const matchIds = [
			...new Set(
				predictionDocs
					.map((doc) => doc.data().matchId)
					.filter((matchId): matchId is string => typeof matchId === 'string'),
			),
		];
		const matchDocs =
			matchIds.length > 0
				? await db.getAll(
						...matchIds.map((matchId) => db.collection('matches').doc(matchId)),
					)
				: [];
		const matchesById = new Map<string, admin.firestore.DocumentData>();
		matchDocs.forEach((doc) => {
			if (doc.exists) matchesById.set(doc.id, doc.data()!);
		});

		const grouped = new Map<
			string,
			Array<{ displayName: string; homeGuess: number; awayGuess: number }>
		>();
		const currentUserPredicted = new Set<string>();

		for (const predictionDoc of predictionDocs) {
			const prediction = predictionDoc.data();
			const matchId = prediction.matchId;
			const predictionUserId = prediction.userId;
			if (typeof matchId !== 'string' || typeof predictionUserId !== 'string') {
				continue;
			}

			const match = matchesById.get(matchId);
			if (!match) continue;
			const leagueId = match.leagueId;
			if (
				leagueIds.length > 0 &&
				(typeof leagueId !== 'string' || !leagueIds.includes(leagueId))
			) {
				continue;
			}

			if (predictionUserId === uid) {
				currentUserPredicted.add(matchId);
			}

			grouped.set(matchId, [
				...(grouped.get(matchId) ?? []),
				{
					displayName: displayNames.get(predictionUserId) ?? 'Anonimo',
					homeGuess:
						typeof prediction.homeGuess === 'number' ? prediction.homeGuess : 0,
					awayGuess:
						typeof prediction.awayGuess === 'number' ? prediction.awayGuess : 0,
				},
			]);
		}

		const matches = [...grouped.entries()]
			.map(([matchId, predictions]) => {
				const match = matchesById.get(matchId)!;
				const kickoff = match.kickoff as
					| admin.firestore.Timestamp
					| undefined;
				const userHasPredicted = currentUserPredicted.has(matchId);
				return {
					matchId,
					homeTeam:
						typeof match.homeTeam === 'string' ? match.homeTeam : 'Local',
					awayTeam:
						typeof match.awayTeam === 'string' ? match.awayTeam : 'Visitante',
					kickoffMillis: kickoff?.toMillis() ?? null,
					userHasPredicted,
					predictionCount: predictions.length,
					predictions: userHasPredicted
						? predictions.sort((a, b) =>
								a.displayName.localeCompare(b.displayName),
							)
						: [],
				};
			})
			.sort((a, b) => {
				const aKickoff = a.kickoffMillis ?? 0;
				const bKickoff = b.kickoffMillis ?? 0;
				return aKickoff - bKickoff;
			});

		return { matches };
	},
);
