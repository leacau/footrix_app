import * as admin from 'firebase-admin';

import { FIFA_MATCHES_BASE_URL, FIFA_USER_AGENT } from './config';

type JsonRecord = Record<string, unknown>;

type FifaTeam = JsonRecord & {
	TeamName?: unknown;
	Score?: unknown;
	PictureUrl?: unknown;
};

type FifaMatch = JsonRecord & {
	IdMatch?: unknown;
	Date?: unknown;
	Home?: FifaTeam;
	Away?: FifaTeam;
	MatchStatus?: unknown;
	CompetitionName?: unknown;
	GroupName?: unknown;
	StageName?: unknown;
	Stadium?: JsonRecord;
};

export type FifaSyncSummary = {
	matchesSynced: number;
	leaguesSynced: number;
};

async function predictionLockHoursBefore(): Promise<number> {
	const doc = await admin
		.firestore()
		.collection('app_config')
		.doc('predictions')
		.get();
	const value = doc.data()?.lockHoursBefore;
	return typeof value === 'number' ? value : 12;
}

const FIFA_LANGUAGE = 'es';
const FIFA_COUNT = '500';
const FIFA_PAST_DAYS = 30;
const FIFA_FUTURE_DAYS = 90;
const FIFA_CHUNK_DAYS = 1;
const requestCache = new Map<string, Promise<FifaMatch[]>>();

function isRecord(value: unknown): value is JsonRecord {
	return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function addDays(date: Date, days: number): Date {
	const copy = new Date(date);
	copy.setUTCDate(copy.getUTCDate() + days);
	return copy;
}

function startOfUtcDay(date: Date): Date {
	return new Date(
		Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()),
	);
}

function endOfUtcDay(date: Date): Date {
	const start = startOfUtcDay(date);
	return new Date(start.getTime() + 24 * 60 * 60 * 1000 - 1000);
}

function fifaIso(date: Date): string {
	return date.toISOString().replace(/\.\d{3}Z$/, 'Z');
}

export function fifaSyncRange(): { from: Date; to: Date } {
	const today = startOfUtcDay(new Date());
	return {
		from: addDays(today, -FIFA_PAST_DAYS),
		to: endOfUtcDay(addDays(today, FIFA_FUTURE_DAYS)),
	};
}

export function fifaSyncRanges(): Array<{ from: Date; to: Date }> {
	const range = fifaSyncRange();
	const ranges: Array<{ from: Date; to: Date }> = [];
	let cursor = range.from;

	while (cursor <= range.to) {
		const chunkEnd = endOfUtcDay(addDays(cursor, FIFA_CHUNK_DAYS - 1));
		ranges.push({
			from: cursor,
			to: chunkEnd < range.to ? chunkEnd : range.to,
		});
		cursor = startOfUtcDay(addDays(cursor, FIFA_CHUNK_DAYS));
	}

	return ranges;
}

function extractMatches(payload: unknown): FifaMatch[] {
	if (Array.isArray(payload)) {
		return payload.filter(isRecord) as FifaMatch[];
	}

	if (!isRecord(payload)) return [];
	const matchKeys = [
		'Results',
		'results',
		'Matches',
		'matches',
		'Items',
		'items',
		'Data',
		'data',
	];

	for (const key of matchKeys) {
		const value = payload[key];
		if (Array.isArray(value)) {
			return value.filter(isRecord) as FifaMatch[];
		}
	}

	return [];
}

async function fetchFifaMatches(from: Date, to: Date): Promise<FifaMatch[]> {
	const cacheKey = `${from.toISOString()}_${to.toISOString()}`;
	if (!requestCache.has(cacheKey)) {
		requestCache.set(
			cacheKey,
			(async () => {
				const url = new URL(FIFA_MATCHES_BASE_URL);
				url.searchParams.set('from', fifaIso(from));
				url.searchParams.set('to', fifaIso(to));
				url.searchParams.set('language', FIFA_LANGUAGE);
				url.searchParams.set('count', FIFA_COUNT);

				const response = await fetch(url.toString(), {
					headers: {
						'User-Agent': FIFA_USER_AGENT,
						Accept: 'application/json',
					},
				});

				if (!response.ok) {
					const detail = await response.text();
					throw new Error(`FIFA HTTP ${response.status}: ${detail}`);
				}

				const payload = await response.json();
				const matches = extractMatches(payload);
				if (
					isRecord(payload) &&
					payload.ContinuationToken != null &&
					matches.length >= Number.parseInt(FIFA_COUNT, 10)
				) {
					console.warn(
						`FIFA range ${fifaIso(from)} / ${fifaIso(to)} returned ${matches.length} matches with continuation token`,
					);
				}
				return matches;
			})(),
		);
	}
	return requestCache.get(cacheKey)!;
}

function textFromRecord(record: JsonRecord): string | null {
	const candidates = [
		record.Description,
		record.Name,
		record.ShortName,
		record.Abbreviation,
		record.Value,
	];
	for (const candidate of candidates) {
		if (typeof candidate === 'string' && candidate.trim() !== '') {
			return candidate.trim();
		}
	}
	return null;
}

function localizedText(value: unknown): string {
	if (typeof value === 'string') return value.trim();
	const items = Array.isArray(value) ? value : isRecord(value) ? [value] : [];
	const records = items.filter(isRecord);
	if (records.length === 0) return '';

	const spanish =
		records.find((item) => {
			const locale = item.Locale;
			return typeof locale === 'string' && locale.toLowerCase().includes('es');
		}) ?? records[0];

	return textFromRecord(spanish) ?? '';
}

function parseScore(value: unknown): number | null {
	if (typeof value === 'number' && Number.isFinite(value)) return value;
	if (typeof value === 'string' && value.trim() !== '') {
		const parsed = Number.parseInt(value, 10);
		return Number.isNaN(parsed) ? null : parsed;
	}
	return null;
}

function fifaPictureUrl(value: unknown): string | null {
	if (typeof value !== 'string' || value.trim() === '') return null;
	return value
		.trim()
		.replace(/\{format\}/g, 'sq')
		.replace(/\{size\}/g, '2');
}

function statusNumber(value: unknown): number | null {
	if (typeof value === 'number') return value;
	if (typeof value === 'string' && value.trim() !== '') {
		const parsed = Number.parseInt(value, 10);
		return Number.isNaN(parsed) ? null : parsed;
	}
	if (isRecord(value)) {
		return statusNumber(value.IdStatus ?? value.Status ?? value.Value);
	}
	return null;
}

function statusText(value: unknown): string {
	if (typeof value === 'string') return value.toLowerCase();
	if (isRecord(value)) {
		return [
			value.Description,
			value.Name,
			value.ShortName,
			value.Status,
			value.Value,
		]
			.filter((item): item is string => typeof item === 'string')
			.join(' ')
			.toLowerCase();
	}
	return '';
}

function mapFifaStatus(
	matchStatus: unknown,
	homeScore: number | null,
	awayScore: number | null,
): string {
	const numericStatus = statusNumber(matchStatus);
	const normalizedStatus = statusText(matchStatus);
	if (
		numericStatus === 3 ||
		normalizedStatus.includes('live') ||
		normalizedStatus.includes('en vivo') ||
		normalizedStatus.includes('in play')
	) {
		return 'live';
	}
	if (
		normalizedStatus.includes('finish') ||
		normalizedStatus.includes('final') ||
		normalizedStatus.includes('full time')
	) {
		return 'finished';
	}
	if (homeScore != null && awayScore != null) {
		return 'finished';
	}
	return 'scheduled';
}

function normalizedLeagueId(name: string): string {
	return name
		.toLowerCase()
		.normalize('NFD')
		.replace(/[\u0300-\u036f]/g, '')
		.replace(/[^a-z0-9]+/g, '-')
		.replace(/^-+|-+$/g, '')
		.slice(0, 120);
}

function matchDate(value: unknown): Date | null {
	if (typeof value !== 'string') return null;
	const date = new Date(value);
	return Number.isNaN(date.getTime()) ? null : date;
}

export async function syncFifaMatches(
	from: Date,
	to: Date,
): Promise<FifaSyncSummary> {
	const matches = await fetchFifaMatches(from, to);
	const db = admin.firestore();
	const writer = db.bulkWriter();
	const leagues = new Map<string, { name: string; phase: string }>();
	const lockHoursBefore = await predictionLockHoursBefore();
	let synced = 0;

	for (const match of matches) {
		const id = match.IdMatch;
		const kickoff = matchDate(match.Date);
		const home = isRecord(match.Home) ? match.Home : null;
		const away = isRecord(match.Away) ? match.Away : null;
		if (id == null || !kickoff || !home || !away) continue;

		const homeTeam = localizedText(home.TeamName);
		const awayTeam = localizedText(away.TeamName);
		if (!homeTeam || !awayTeam) continue;

		const competitionName = localizedText(match.CompetitionName);
		const phase =
			localizedText(match.GroupName) || localizedText(match.StageName);
		const leagueId = competitionName
			? normalizedLeagueId(competitionName)
			: 'fifa';
		const homeScore = parseScore(home.Score);
		const awayScore = parseScore(away.Score);
		const status = mapFifaStatus(match.MatchStatus, homeScore, awayScore);
		const stadium = isRecord(match.Stadium) ? match.Stadium : null;
		const venue = stadium ? localizedText(stadium.Name) : null;
		const venueCity = stadium ? localizedText(stadium.CityName) : null;

		writer.set(
			db.collection('matches').doc(`fifa_${String(id)}`),
			{
				homeTeam,
				awayTeam,
				phase,
				kickoff: admin.firestore.Timestamp.fromDate(kickoff),
				status,
				homeScore,
				awayScore,
				lockHoursBefore,
				leagueId,
				apiSource: 'fifa',
				apiMatchId: String(id),
				competitionName: competitionName || null,
				competitionEmblem: null,
				venue: venue || null,
				venueCity: venueCity || null,
				homeTeamLogo: fifaPictureUrl(home.PictureUrl),
				awayTeamLogo: fifaPictureUrl(away.PictureUrl),
				updatedAt: admin.firestore.FieldValue.serverTimestamp(),
				syncedAt: admin.firestore.FieldValue.serverTimestamp(),
				...(status === 'finished'
					? { finishedAt: admin.firestore.FieldValue.serverTimestamp() }
					: {}),
			},
			{ merge: true },
		);

		if (competitionName) {
			leagues.set(leagueId, { name: competitionName, phase });
		}
		synced++;
	}

	for (const [id, league] of leagues.entries()) {
		writer.set(
			db.collection('leagues').doc(id),
			{
				name: league.name,
				shortName: league.name,
				country: 'FIFA',
				logo: null,
				apiSource: 'fifa',
				filterKeywords: [league.name],
				active: true,
				syncEnabled: true,
				updatedAt: admin.firestore.FieldValue.serverTimestamp(),
			},
			{ merge: true },
		);
	}

	await writer.close();
	return { matchesSynced: synced, leaguesSynced: leagues.size };
}
