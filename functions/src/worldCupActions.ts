import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

const WORLD_CUP_LEAGUE_ID = 'copa-mundial-de-la-fifa';

type PredictionInput = {
	homeGuess?: unknown;
	awayGuess?: unknown;
	winnerKey?: unknown;
};

type CleanPrediction = {
	homeGuess: number;
	awayGuess: number;
	winnerKey?: string;
};

type WorldCupMatchDoc = admin.firestore.QueryDocumentSnapshot;

type StandingRow = {
	key: string;
	name: string;
	groupName: string;
	points: number;
	goalsFor: number;
	goalsAgainst: number;
};

type Simulation = {
	standingsByGroup: Map<string, StandingRow[]>;
	qualifiedByKey: Map<string, { position: number; groupName: string }>;
	winnersByMatchNumber: Map<number, string>;
};

function requireAuth(context: functions.https.CallableContext): string {
	if (!context.auth) {
		throw new functions.https.HttpsError('unauthenticated', 'No autenticado');
	}
	return context.auth.uid;
}

function requireAdmin(context: functions.https.CallableContext): void {
	if (context.auth?.token.admin !== true) {
		throw new functions.https.HttpsError(
			'permission-denied',
			'No tenes permisos de administrador',
		);
	}
}

function isWorldCupMatch(match: admin.firestore.DocumentData): boolean {
	return (
		match.worldCup2026 === true ||
		match.leagueId === WORLD_CUP_LEAGUE_ID ||
		match.competitionName === 'Copa Mundial de la FIFA™'
	);
}

function predictionPoints(
	homeGuess: number,
	awayGuess: number,
	homeScore: number,
	awayScore: number,
): number {
	if (homeGuess === homeScore && awayGuess === awayScore) return 3;
	if (
		(homeGuess > awayGuess && homeScore > awayScore) ||
		(homeGuess < awayGuess && homeScore < awayScore) ||
		(homeGuess === awayGuess && homeScore === awayScore)
	) {
		return 1;
	}
	return 0;
}

async function worldCupMatches() {
	const snap = await admin
		.firestore()
		.collection('matches')
		.where('leagueId', '==', WORLD_CUP_LEAGUE_ID)
		.orderBy('kickoff', 'asc')
		.get();
	return snap.docs.filter((doc) => isWorldCupMatch(doc.data()));
}

function standingSort(a: StandingRow, b: StandingRow): number {
	if (b.points !== a.points) return b.points - a.points;
	const gdA = a.goalsFor - a.goalsAgainst;
	const gdB = b.goalsFor - b.goalsAgainst;
	if (gdB !== gdA) return gdB - gdA;
	if (b.goalsFor !== a.goalsFor) return b.goalsFor - a.goalsFor;
	return a.name.localeCompare(b.name);
}

function addStandingResult(
	row: StandingRow,
	scored: number,
	conceded: number,
) {
	row.goalsFor += scored;
	row.goalsAgainst += conceded;
	if (scored > conceded) row.points += 3;
	else if (scored === conceded) row.points += 1;
}

function matchNumber(match: admin.firestore.DocumentData): number | null {
	return typeof match.matchNumber === 'number' ? match.matchNumber : null;
}

function teamName(match: admin.firestore.DocumentData, home: boolean): string {
	const name = home ? match.homeTeam : match.awayTeam;
	const placeholder = home ? match.placeHolderA : match.placeHolderB;
	if (typeof name === 'string' && name.trim() && name !== 'Por definir') {
		return name.trim();
	}
	return typeof placeholder === 'string' && placeholder.trim()
		? placeholder.trim()
		: 'Por definir';
}

function teamKey(match: admin.firestore.DocumentData, home: boolean): string {
	const id = home ? match.homeTeamId : match.awayTeamId;
	const placeholder = home ? match.placeHolderA : match.placeHolderB;
	const name = home ? match.homeTeam : match.awayTeam;
	if (typeof id === 'string' && id.trim()) return `team:${id.trim()}`;
	if (typeof name === 'string' && name.trim() && name !== 'Por definir') {
		return `name:${name.trim()}`;
	}
	return `slot:${typeof placeholder === 'string' ? placeholder.trim() : 'tbd'}`;
}

function buildStandings(
	matches: WorldCupMatchDoc[],
	scoreForMatch: (matchDoc: WorldCupMatchDoc) => CleanPrediction | null,
): Map<string, StandingRow[]> {
	const tables = new Map<string, Map<string, StandingRow>>();
	for (const matchDoc of matches) {
		const match = matchDoc.data();
		const groupName =
			typeof match.groupName === 'string' ? match.groupName.trim() : '';
		if (!groupName) continue;
		const table = tables.get(groupName) ?? new Map<string, StandingRow>();
		tables.set(groupName, table);
		const homeKey = teamKey(match, true);
		const awayKey = teamKey(match, false);
		if (!table.has(homeKey)) {
			table.set(homeKey, {
				key: homeKey,
				name: teamName(match, true),
				groupName,
				points: 0,
				goalsFor: 0,
				goalsAgainst: 0,
			});
		}
		if (!table.has(awayKey)) {
			table.set(awayKey, {
				key: awayKey,
				name: teamName(match, false),
				groupName,
				points: 0,
				goalsFor: 0,
				goalsAgainst: 0,
			});
		}
		const score = scoreForMatch(matchDoc);
		if (!score) continue;
		addStandingResult(table.get(homeKey)!, score.homeGuess, score.awayGuess);
		addStandingResult(table.get(awayKey)!, score.awayGuess, score.homeGuess);
	}

	const result = new Map<string, StandingRow[]>();
	for (const [groupName, table] of tables.entries()) {
		result.set(groupName, [...table.values()].sort(standingSort));
	}
	return result;
}

function resolveQualified(standings: Map<string, StandingRow[]>) {
	const qualified = new Map<string, { position: number; groupName: string }>();
	const thirds: Array<StandingRow & { position: number }> = [];
	for (const [groupName, rows] of standings.entries()) {
		rows.slice(0, 2).forEach((row, index) => {
			qualified.set(row.key, { position: index + 1, groupName });
		});
		if (rows.length > 2) thirds.push({ ...rows[2], position: 3 });
	}
	thirds.sort(standingSort);
	for (const row of thirds.slice(0, 8)) {
		qualified.set(row.key, { position: 3, groupName: row.groupName });
	}
	return qualified;
}

function groupLetter(groupName: string): string {
	return groupName.replace('Grupo ', '').trim();
}

function resolveSlot(
	slot: unknown,
	standings: Map<string, StandingRow[]>,
	thirds: StandingRow[],
	usedThirds: Set<string>,
	winners: Map<number, string>,
	runnersUp: Map<number, string>,
): string | null {
	if (typeof slot !== 'string' || !slot.trim()) return null;
	const clean = slot.trim();
	const direct = clean.match(/^([12])([A-L])$/);
	if (direct) {
		const position = Number.parseInt(direct[1], 10) - 1;
		for (const [groupName, rows] of standings.entries()) {
			if (groupLetter(groupName) === direct[2]) return rows[position]?.key ?? null;
		}
	}

	const third = clean.match(/^3([A-L]+)$/);
	if (third) {
		const allowed = new Set(third[1].split(''));
		const selected = thirds.find(
			(row) => allowed.has(groupLetter(row.groupName)) && !usedThirds.has(row.key),
		);
		if (!selected) return null;
		usedThirds.add(selected.key);
		return selected.key;
	}

	const winner = clean.match(/^W(\d+)$/);
	if (winner) return winners.get(Number.parseInt(winner[1], 10)) ?? null;

	const runnerUp = clean.match(/^RU(\d+)$/);
	if (runnerUp) return runnersUp.get(Number.parseInt(runnerUp[1], 10)) ?? null;

	return null;
}

function simulateWorldCup(
	matches: WorldCupMatchDoc[],
	predictions: Record<string, CleanPrediction>,
): Simulation {
	const standingsByGroup = buildStandings(
		matches,
		(matchDoc) => predictions[matchDoc.id] ?? null,
	);
	const qualifiedByKey = resolveQualified(standingsByGroup);
	const thirds = [...standingsByGroup.values()]
		.map((rows) => rows[2])
		.filter((row): row is StandingRow => row != null)
		.sort(standingSort);
	const usedThirds = new Set<string>();
	const winnersByMatchNumber = new Map<number, string>();
	const runnersUpByMatchNumber = new Map<number, string>();
	const sortedKnockout = matches
		.filter((doc) => {
			const match = doc.data();
			return !(typeof match.groupName === 'string' && match.groupName.trim());
		})
		.sort((a, b) => (matchNumber(a.data()) ?? 0) - (matchNumber(b.data()) ?? 0));

	for (const matchDoc of sortedKnockout) {
		const match = matchDoc.data();
		const number = matchNumber(match);
		if (number == null) continue;
		const homeKey =
			resolveSlot(
				match.placeHolderA,
				standingsByGroup,
				thirds,
				usedThirds,
				winnersByMatchNumber,
				runnersUpByMatchNumber,
			) ?? teamKey(match, true);
		const awayKey =
			resolveSlot(
				match.placeHolderB,
				standingsByGroup,
				thirds,
				usedThirds,
				winnersByMatchNumber,
				runnersUpByMatchNumber,
			) ?? teamKey(match, false);
		const prediction = predictions[matchDoc.id];
		if (!prediction) continue;

		let winnerKey: string | null = null;
		let runnerUpKey: string | null = null;
		if (prediction.homeGuess > prediction.awayGuess) {
			winnerKey = homeKey;
			runnerUpKey = awayKey;
		} else if (prediction.awayGuess > prediction.homeGuess) {
			winnerKey = awayKey;
			runnerUpKey = homeKey;
		} else if (
			prediction.winnerKey === homeKey ||
			prediction.winnerKey === awayKey
		) {
			winnerKey = prediction.winnerKey;
			runnerUpKey = winnerKey === homeKey ? awayKey : homeKey;
		}
		if (winnerKey) winnersByMatchNumber.set(number, winnerKey);
		if (runnerUpKey) runnersUpByMatchNumber.set(number, runnerUpKey);
	}

	return { standingsByGroup, qualifiedByKey, winnersByMatchNumber };
}

function actualPredictions(matches: WorldCupMatchDoc[]): Record<string, CleanPrediction> {
	const actual: Record<string, CleanPrediction> = {};
	for (const matchDoc of matches) {
		const match = matchDoc.data();
		if (match.status !== 'finished') continue;
		if (typeof match.homeScore !== 'number' || typeof match.awayScore !== 'number') {
			continue;
		}
		let winnerKey: string | undefined;
		if (match.homeScore > match.awayScore) winnerKey = teamKey(match, true);
		else if (match.awayScore > match.homeScore) winnerKey = teamKey(match, false);
		else if (typeof match.winnerTeamId === 'string' && match.winnerTeamId.trim()) {
			winnerKey = `team:${match.winnerTeamId.trim()}`;
		} else if (
			typeof match.winnerTeamName === 'string' &&
			match.winnerTeamName.trim()
		) {
			winnerKey = `name:${match.winnerTeamName.trim()}`;
		}
		actual[matchDoc.id] = {
			homeGuess: match.homeScore,
			awayGuess: match.awayScore,
			...(winnerKey ? { winnerKey } : {}),
		};
	}
	return actual;
}

async function firstWorldCupKickoff(): Promise<number | null> {
	const matches = await worldCupMatches();
	let first: number | null = null;
	for (const doc of matches) {
		const kickoff = doc.data().kickoff as admin.firestore.Timestamp | undefined;
		if (!kickoff) continue;
		const millis = kickoff.toMillis();
		if (first == null || millis < first) first = millis;
	}
	return first;
}

function sanitizePredictions(
	raw: unknown,
	validMatchIds: Set<string>,
): Record<string, CleanPrediction> {
	if (typeof raw !== 'object' || raw == null || Array.isArray(raw)) {
		throw new functions.https.HttpsError(
			'invalid-argument',
			'Predicciones invalidas',
		);
	}

	const clean: Record<string, CleanPrediction> = {};
	for (const [matchId, value] of Object.entries(
		raw as Record<string, PredictionInput>,
	)) {
		if (!validMatchIds.has(matchId)) continue;
		if (typeof value !== 'object' || value == null || Array.isArray(value)) {
			continue;
		}
		const rawHomeGuess = value.homeGuess;
		const rawAwayGuess = value.awayGuess;
		if (
			typeof rawHomeGuess !== 'number' ||
			typeof rawAwayGuess !== 'number' ||
			!Number.isInteger(rawHomeGuess) ||
			!Number.isInteger(rawAwayGuess)
		) {
			continue;
		}
		if (
			rawHomeGuess < 0 ||
			rawAwayGuess < 0 ||
			rawHomeGuess > 30 ||
			rawAwayGuess > 30
		) {
			throw new functions.https.HttpsError(
				'invalid-argument',
				'Resultado fuera de rango',
			);
		}
		const winnerKey =
			typeof value.winnerKey === 'string' && value.winnerKey.trim()
				? value.winnerKey.trim().slice(0, 160)
				: undefined;
		clean[matchId] = {
			homeGuess: rawHomeGuess,
			awayGuess: rawAwayGuess,
			...(winnerKey ? { winnerKey } : {}),
		};
	}
	return clean;
}

export async function updateWorldCupScoreForUser(
	userId: string,
	matchDocs: WorldCupMatchDoc[],
	predictions: Record<string, CleanPrediction>,
) {
	const db = admin.firestore();
	const userDoc = await db.collection('users').doc(userId).get();
	const displayName =
		typeof userDoc.data()?.displayName === 'string' &&
		userDoc.data()!.displayName.trim()
			? userDoc.data()!.displayName.trim()
			: 'Anonimo';

	let matchPoints = 0;
	let gradedPredictions = 0;
	for (const matchDoc of matchDocs) {
		const match = matchDoc.data();
		const prediction = predictions[matchDoc.id];
		if (!prediction) continue;
		if (match.status !== 'finished') continue;
		const homeScore = match.homeScore;
		const awayScore = match.awayScore;
		if (typeof homeScore !== 'number' || typeof awayScore !== 'number') continue;
		matchPoints += predictionPoints(
			prediction.homeGuess,
			prediction.awayGuess,
			homeScore,
			awayScore,
		);
		gradedPredictions++;
	}

	const actual = simulateWorldCup(matchDocs, actualPredictions(matchDocs));
	const predicted = simulateWorldCup(matchDocs, predictions);
	let groupPoints = 0;
	const groupStageMatches = matchDocs.filter((doc) => {
		const groupName = doc.data().groupName;
		return typeof groupName === 'string' && groupName.trim();
	});
	const groupStageComplete =
		groupStageMatches.length >= 72 &&
		groupStageMatches.every((doc) => doc.data().status === 'finished');
	if (groupStageComplete) {
		for (const [team, actualQualified] of actual.qualifiedByKey.entries()) {
			const predictedQualified = predicted.qualifiedByKey.get(team);
			if (!predictedQualified) continue;
			groupPoints +=
				predictedQualified.groupName === actualQualified.groupName &&
				predictedQualified.position === actualQualified.position
					? 5
					: 1;
		}
	}

	let knockoutPoints = 0;
	for (const matchDoc of matchDocs) {
		const match = matchDoc.data();
		if (match.status !== 'finished') continue;
		const number = matchNumber(match);
		if (number == null || number < 73 || number === 103) continue;
		const predictedWinner = predicted.winnersByMatchNumber.get(number);
		const actualWinner = actual.winnersByMatchNumber.get(number);
		if (predictedWinner && actualWinner && predictedWinner === actualWinner) {
			knockoutPoints += 5;
		}
	}

	const totalPoints = matchPoints + groupPoints + knockoutPoints;
	const predictionCount = Object.keys(predictions).length;
	await db.collection('world_cup_scores').doc(userId).set(
		{
			userId,
			displayName,
			totalPoints,
			matchPoints,
			groupPoints,
			knockoutPoints,
			predictionCount,
			gradedPredictions,
			average: predictionCount > 0 ? totalPoints / predictionCount : 0,
			updatedAt: admin.firestore.FieldValue.serverTimestamp(),
		},
		{ merge: true },
	);
}

export async function recalculateWorldCupUserScore(userId: string) {
	const matches = await worldCupMatches();
	const predictionDoc = await admin
		.firestore()
		.collection('world_cup_predictions')
		.doc(userId)
		.get();
	const predictions = sanitizePredictions(
		predictionDoc.data()?.matchPredictions ?? {},
		new Set(matches.map((matchDoc) => matchDoc.id)),
	);
	await updateWorldCupScoreForUser(userId, matches, predictions);
}

export const saveWorldCupPredictions = functions.https.onCall(
	async (data, context) => {
		const uid = requireAuth(context);
		const userDoc = await admin.firestore().collection('users').doc(uid).get();
		const permissions = userDoc.data()?.predictionPermissions;
		if (permissions?.blocked === true) {
			throw new functions.https.HttpsError(
				'permission-denied',
				'Tu usuario no tiene habilitadas las predicciones',
			);
		}
		const bypassLocks = permissions?.bypassLocks === true;
		const matches = await worldCupMatches();
		if (matches.length === 0) {
			throw new functions.https.HttpsError(
				'failed-precondition',
				'Todavia no hay partidos del Mundial sincronizados',
			);
		}

		const lockDeadline = await firstWorldCupKickoff();
		if (!bypassLocks && lockDeadline != null && Date.now() >= lockDeadline) {
			throw new functions.https.HttpsError(
				'failed-precondition',
				'Las predicciones del Mundial ya estan cerradas',
			);
		}

		const validMatchIds = new Set(matches.map((doc) => doc.id));
		const predictions = sanitizePredictions(
			data.matchPredictions,
			validMatchIds,
		);

		await admin.firestore().collection('world_cup_predictions').doc(uid).set(
			{
				userId: uid,
				matchPredictions: predictions,
				predictionCount: Object.keys(predictions).length,
				lockDeadlineMillis: lockDeadline,
				updatedAt: admin.firestore.FieldValue.serverTimestamp(),
			},
			{ merge: true },
		);

		await updateWorldCupScoreForUser(uid, matches, predictions);
		return {
			success: true,
			predictionCount: Object.keys(predictions).length,
			lockDeadlineMillis: lockDeadline,
		};
	},
);

export const recalculateWorldCupScores = functions
	.runWith({ timeoutSeconds: 540 })
	.https.onCall(async (_data, context) => {
		requireAdmin(context);
		const matches = await worldCupMatches();
		const predictionsSnap = await admin
			.firestore()
			.collection('world_cup_predictions')
			.get();

		let updated = 0;
		for (const doc of predictionsSnap.docs) {
			const data = doc.data();
			const raw = data.matchPredictions ?? {};
			const predictions = sanitizePredictions(
				raw,
				new Set(matches.map((matchDoc) => matchDoc.id)),
			);
			await updateWorldCupScoreForUser(doc.id, matches, predictions);
			updated++;
		}

		return { success: true, updated };
	});
