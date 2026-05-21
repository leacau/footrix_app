import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import {
	ARGENTINA_LEAGUE,
	FOOTBALL_DATA_BASE_URL,
	FOOTBALL_DATA_COMPETITIONS,
	FOOTBALL_DATA_TOKEN,
	THESPORTSDB_BASE_URL,
} from './config';

function toIsoDate(date: Date): string {
	return date.toISOString().slice(0, 10);
}

function addDays(date: Date, days: number): Date {
	const copy = new Date(date);
	copy.setUTCDate(copy.getUTCDate() + days);
	return copy;
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

function score(value: unknown): number | null {
	if (typeof value === 'number') return value;
	if (typeof value === 'string' && value.trim()) {
		const parsed = Number.parseInt(value, 10);
		return Number.isNaN(parsed) ? null : parsed;
	}
	return null;
}

async function updateFootballDataResults(): Promise<number> {
	const token = FOOTBALL_DATA_TOKEN.value();
	if (!token) throw new Error('FOOTBALL_DATA_TOKEN is not configured');

	const today = new Date();
	const url = new URL(`${FOOTBALL_DATA_BASE_URL}/matches`);
	url.searchParams.set(
		'competitions',
		Object.keys(FOOTBALL_DATA_COMPETITIONS).join(','),
	);
	url.searchParams.set('dateFrom', toIsoDate(addDays(today, -1)));
	url.searchParams.set('dateTo', toIsoDate(addDays(today, 1)));

	const response = await fetch(url.toString(), {
		headers: { 'X-Auth-Token': token, 'User-Agent': 'Footrix/1.0' },
	});
	if (!response.ok) throw new Error(`football-data HTTP ${response.status}`);

	const data = await response.json();
	const matches = Array.isArray(data.matches) ? data.matches : [];
	let updated = 0;

	for (const match of matches) {
		if (!match.id) continue;
		const updateData: admin.firestore.UpdateData<admin.firestore.DocumentData> = {
			status: mapFootballDataStatus(match.status),
			homeScore: score(match.score?.fullTime?.home),
			awayScore: score(match.score?.fullTime?.away),
			updatedAt: admin.firestore.FieldValue.serverTimestamp(),
			syncedAt: admin.firestore.FieldValue.serverTimestamp(),
		};
		if (updateData.status === 'finished') {
			updateData.finishedAt = admin.firestore.FieldValue.serverTimestamp();
		}
		await admin
			.firestore()
			.collection('matches')
			.doc(`fd_${match.id}`)
			.set(updateData, { merge: true });
		updated++;
	}

	return updated;
}

async function updateArgentinaResults(): Promise<number> {
	const baseUrl = THESPORTSDB_BASE_URL.value().replace(/\/$/, '');
	const url = new URL(`${baseUrl}/eventspastleague.php`);
	url.searchParams.set('id', ARGENTINA_LEAGUE.apiLeagueId);

	const response = await fetch(url, {
		headers: { 'User-Agent': 'Footrix/1.0' },
	});
	if (!response.ok) throw new Error(`TheSportsDB HTTP ${response.status}`);

	const data = await response.json();
	const events = Array.isArray(data.events) ? data.events : [];
	let updated = 0;

	for (const event of events) {
		if (!event.idEvent) continue;
		const status = mapSportsDbStatus(event.strStatus);
		const updateData: admin.firestore.UpdateData<admin.firestore.DocumentData> = {
			status,
			homeScore: score(event.intHomeScore),
			awayScore: score(event.intAwayScore),
			updatedAt: admin.firestore.FieldValue.serverTimestamp(),
			syncedAt: admin.firestore.FieldValue.serverTimestamp(),
		};
		if (status === 'finished') {
			updateData.finishedAt = admin.firestore.FieldValue.serverTimestamp();
		}
		await admin
			.firestore()
			.collection('matches')
			.doc(`tsdb_${event.idEvent}`)
			.set(updateData, { merge: true });
		updated++;
	}

	return updated;
}

export const pollMatchResults = functions
	.runWith({ secrets: [FOOTBALL_DATA_TOKEN] })
	.pubsub.schedule('every 6 hours')
	.timeZone('America/Argentina/Buenos_Aires')
	.onRun(async () => {
		const footballDataUpdated = await updateFootballDataResults();
		const argentinaUpdated = await updateArgentinaResults();
		console.log(
			`Result poll complete. football-data=${footballDataUpdated}, argentina=${argentinaUpdated}`,
		);
		return null;
	});
