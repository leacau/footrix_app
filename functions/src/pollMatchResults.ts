import * as functions from 'firebase-functions';

import { syncFifaMatches } from './fifaApi';

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

export const pollMatchResults = functions.pubsub
	.schedule('every 5 minutes')
	.timeZone('America/Argentina/Buenos_Aires')
	.onRun(async () => {
		const today = startOfUtcDay(new Date());
		const yesterdaySummary = await syncFifaMatches(
			addDays(today, -1),
			endOfUtcDay(addDays(today, -1)),
		);
		const todaySummary = await syncFifaMatches(today, endOfUtcDay(today));
		const summary = {
			matchesSynced:
				yesterdaySummary.matchesSynced + todaySummary.matchesSynced,
			leaguesSynced:
				yesterdaySummary.leaguesSynced + todaySummary.leaguesSynced,
		};
		console.log(
			`Result poll complete. fifa=${summary.matchesSynced}, leagues=${summary.leaguesSynced}`,
		);
		return null;
	});
