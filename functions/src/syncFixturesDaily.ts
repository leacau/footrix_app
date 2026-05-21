import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

import {
	ARGENTINA_LEAGUE,
	FOOTBALL_DATA_BASE_URL,
	FOOTBALL_DATA_COMPETITIONS,
	FOOTBALL_DATA_TOKEN,
	THESPORTSDB_BASE_URL,
} from './config';

type FootballDataMatch = {
	id: number;
	utcDate?: string;
	status?: string;
	matchday?: number;
	stage?: string;
	group?: string | null;
	homeTeam?: { name?: string };
	awayTeam?: { name?: string };
	competition?: { code?: string; name?: string; emblem?: string };
	score?: { fullTime?: { home?: number | null; away?: number | null } };
};

type SportsDbEvent = {
	idEvent?: string;
	strTimestamp?: string;
	dateEvent?: string;
	strTime?: string;
	strHomeTeam?: string;
	strAwayTeam?: string;
	strStatus?: string;
	intHomeScore?: string | null;
	intAwayScore?: string | null;
	intRound?: string | number | null;
	strRound?: string | null;
	strVenue?: string | null;
};

function toIsoDate(date: Date): string {
	return date.toISOString().slice(0, 10);
}

function addDays(date: Date, days: number): Date {
	const copy = new Date(date);
	copy.setUTCDate(copy.getUTCDate() + days);
	return copy;
}

function dateChunks(start: Date, daysAhead: number, chunkSizeDays: number) {
	const chunks: Array<{ from: string; to: string }> = [];
	for (let offset = 0; offset <= daysAhead; offset += chunkSizeDays) {
		const from = addDays(start, offset);
		const to = addDays(start, Math.min(offset + chunkSizeDays - 1, daysAhead));
		chunks.push({ from: toIsoDate(from), to: toIsoDate(to) });
	}
	return chunks;
}

function mapFootballDataStatus(status?: string): string {
	switch (status) {
		case 'IN_PLAY':
		case 'LIVE':
			return 'live';
		case 'PAUSED':
			return 'halftime';
		case 'FINISHED':
			return 'finished';
		case 'POSTPONED':
			return 'postponed';
		case 'SUSPENDED':
		case 'CANCELLED':
			return 'cancelled';
		default:
			return 'scheduled';
	}
}

function mapSportsDbStatus(status?: string | null): string {
	switch (status) {
		case '1H':
		case '2H':
			return 'live';
		case 'HT':
			return 'halftime';
		case 'FT':
		case 'AET':
		case 'PEN':
			return 'finished';
		case 'Postponed':
		case 'Interrupted':
		case 'Suspended':
			return 'postponed';
		case 'Cancelled':
		case 'Abandoned':
			return 'cancelled';
		default:
			return 'scheduled';
	}
}

function parseSportsDbDate(event: SportsDbEvent): admin.firestore.Timestamp | null {
	const candidates = [
		event.strTimestamp ? `${event.strTimestamp.replace(' ', 'T')}Z` : null,
		event.dateEvent && event.strTime
			? `${event.dateEvent}T${event.strTime.replace(/Z$/, '')}Z`
			: null,
	];

	for (const candidate of candidates) {
		if (!candidate) continue;
		const date = new Date(candidate);
		if (!Number.isNaN(date.getTime())) {
			return admin.firestore.Timestamp.fromDate(date);
		}
	}

	return null;
}

function parseNullableScore(value: unknown): number | null {
	if (typeof value === 'number') return value;
	if (typeof value === 'string' && value.trim() !== '') {
		const parsed = Number.parseInt(value, 10);
		return Number.isNaN(parsed) ? null : parsed;
	}
	return null;
}

async function ensureLeagueDocs(): Promise<void> {
	const db = admin.firestore();
	const batch = db.batch();

	for (const [code, league] of Object.entries(FOOTBALL_DATA_COMPETITIONS)) {
		batch.set(
			db.collection('leagues').doc(code),
			{
				name: league.name,
				shortName: code,
				country: league.country,
				apiSource: league.source,
				apiLeagueCode: code,
				active: true,
				syncEnabled: true,
				updatedAt: admin.firestore.FieldValue.serverTimestamp(),
			},
			{ merge: true },
		);
	}

	batch.set(
		db.collection('leagues').doc(ARGENTINA_LEAGUE.id),
		{
			name: ARGENTINA_LEAGUE.name,
			shortName: ARGENTINA_LEAGUE.shortName,
			country: ARGENTINA_LEAGUE.country,
			apiSource: ARGENTINA_LEAGUE.apiSource,
			apiLeagueId: ARGENTINA_LEAGUE.apiLeagueId,
			active: true,
			syncEnabled: true,
			updatedAt: admin.firestore.FieldValue.serverTimestamp(),
		},
		{ merge: true },
	);

	await batch.commit();
}

async function fetchFootballDataMatchesChunk(
	dateFrom: string,
	dateTo: string,
): Promise<FootballDataMatch[]> {
	const token = FOOTBALL_DATA_TOKEN.value();
	if (!token) {
		throw new Error('FOOTBALL_DATA_TOKEN is not configured');
	}

	const competitions = Object.keys(FOOTBALL_DATA_COMPETITIONS).join(',');
	const url = new URL(`${FOOTBALL_DATA_BASE_URL}/matches`);
	url.searchParams.set('competitions', competitions);
	url.searchParams.set('dateFrom', dateFrom);
	url.searchParams.set('dateTo', dateTo);

	const response = await fetch(url.toString(), {
		headers: {
			'X-Auth-Token': token,
			'User-Agent': 'Footrix/1.0',
		},
	});

	if (!response.ok) {
		throw new Error(`football-data HTTP ${response.status}`);
	}

	const data = await response.json();
	return Array.isArray(data.matches) ? data.matches : [];
}

async function fetchFootballDataMatches(
	daysAhead: number,
): Promise<FootballDataMatch[]> {
	const chunks = dateChunks(new Date(), daysAhead, 10);
	const matches: FootballDataMatch[] = [];

	for (const chunk of chunks) {
		const chunkMatches = await fetchFootballDataMatchesChunk(
			chunk.from,
			chunk.to,
		);
		matches.push(...chunkMatches);
	}

	return matches;
}

async function upsertFootballDataMatches(
	matches: FootballDataMatch[],
): Promise<number> {
	const db = admin.firestore();
	let synced = 0;

	for (const match of matches) {
		if (!match.id || !match.utcDate) continue;
		const kickoff = new Date(match.utcDate);
		if (Number.isNaN(kickoff.getTime())) continue;

		const leagueId = match.competition?.code;
		if (!leagueId || !FOOTBALL_DATA_COMPETITIONS[leagueId]) continue;
		const homeTeam = match.homeTeam?.name;
		const awayTeam = match.awayTeam?.name;
		if (!homeTeam || !awayTeam) continue;

		await db
			.collection('matches')
			.doc(`fd_${match.id}`)
			.set(
				{
					homeTeam,
					awayTeam,
					phase:
						match.group ??
						match.stage ??
						(match.matchday ? `Matchday ${match.matchday}` : ''),
					kickoff: admin.firestore.Timestamp.fromDate(kickoff),
					status: mapFootballDataStatus(match.status),
					homeScore: parseNullableScore(match.score?.fullTime?.home),
					awayScore: parseNullableScore(match.score?.fullTime?.away),
					lockHoursBefore: 12,
					leagueId,
					apiSource: 'football-data',
					apiMatchId: match.id.toString(),
					apiLeagueCode: leagueId,
					competitionName: match.competition?.name ?? null,
					competitionEmblem: match.competition?.emblem ?? null,
					matchday: match.matchday ?? null,
					updatedAt: admin.firestore.FieldValue.serverTimestamp(),
					syncedAt: admin.firestore.FieldValue.serverTimestamp(),
				},
				{ merge: true },
			);
		synced++;
	}

	return synced;
}

async function fetchSportsDbEvents(
	endpoint: string,
	params: Record<string, string>,
): Promise<SportsDbEvent[]> {
	const baseUrl = THESPORTSDB_BASE_URL.value().replace(/\/$/, '');
	const url = new URL(`${baseUrl}/${endpoint}`);
	url.searchParams.set('id', ARGENTINA_LEAGUE.apiLeagueId);
	for (const [key, value] of Object.entries(params)) {
		url.searchParams.set(key, value);
	}
	const response = await fetch(url, {
		headers: { 'User-Agent': 'Footrix/1.0' },
	});

	if (!response.ok) {
		throw new Error(`TheSportsDB ${endpoint} HTTP ${response.status}`);
	}

	const data = await response.json();
	return Array.isArray(data.events) ? data.events : [];
}

async function upsertSportsDbArgentina(events: SportsDbEvent[]): Promise<number> {
	const db = admin.firestore();
	let synced = 0;

	for (const event of events) {
		if (!event.idEvent) continue;
		const kickoff = parseSportsDbDate(event);
		if (!kickoff) continue;
		if (!event.strHomeTeam || !event.strAwayTeam) continue;

		await db
			.collection('matches')
			.doc(`tsdb_${event.idEvent}`)
			.set(
				{
					homeTeam: event.strHomeTeam,
					awayTeam: event.strAwayTeam,
					phase:
						event.strRound ??
						(event.intRound != null ? `Round ${event.intRound}` : ''),
					kickoff,
					status: mapSportsDbStatus(event.strStatus),
					homeScore: parseNullableScore(event.intHomeScore),
					awayScore: parseNullableScore(event.intAwayScore),
					lockHoursBefore: 12,
					leagueId: ARGENTINA_LEAGUE.id,
					apiSource: 'thesportsdb',
					apiMatchId: event.idEvent,
					venue: event.strVenue ?? null,
					updatedAt: admin.firestore.FieldValue.serverTimestamp(),
					syncedAt: admin.firestore.FieldValue.serverTimestamp(),
				},
				{ merge: true },
			);
		synced++;
	}

	return synced;
}

export const syncFixturesDaily = functions
	.runWith({ secrets: [FOOTBALL_DATA_TOKEN] })
	.pubsub.schedule('every 12 hours')
	.timeZone('America/Argentina/Buenos_Aires')
	.onRun(async () => {
		await ensureLeagueDocs();

		const footballDataMatches = await fetchFootballDataMatches(45);
		const footballDataSynced =
			await upsertFootballDataMatches(footballDataMatches);

		const argentinaEvents = [
			...(await fetchSportsDbEvents('eventsnextleague.php', {})),
			...(await fetchSportsDbEvents('eventspastleague.php', {})),
		];
		const argentinaSynced = await upsertSportsDbArgentina(argentinaEvents);

		console.log(
			`Fixture sync complete. football-data=${footballDataSynced}, argentina=${argentinaSynced}`,
		);
		return null;
	});

export const syncFixturesNow = functions
	.runWith({ secrets: [FOOTBALL_DATA_TOKEN] })
	.https.onCall(async (_data, context) => {
		if (context.auth?.token.admin !== true) {
			throw new functions.https.HttpsError(
				'permission-denied',
				'No tenes permisos de administrador',
			);
		}

		await ensureLeagueDocs();
		const footballDataMatches = await fetchFootballDataMatches(45);
		const footballDataSynced =
			await upsertFootballDataMatches(footballDataMatches);
		const argentinaSynced = await upsertSportsDbArgentina([
			...(await fetchSportsDbEvents('eventsnextleague.php', {})),
			...(await fetchSportsDbEvents('eventspastleague.php', {})),
		]);

		return { success: true, footballDataSynced, argentinaSynced };
	});

export const refreshLeagueCatalog = functions.https.onCall(
	async (_data, context) => {
		if (context.auth?.token.admin !== true) {
			throw new functions.https.HttpsError(
				'permission-denied',
				'No tenes permisos de administrador',
			);
		}
		await ensureLeagueDocs();
		return { success: true };
	},
);
