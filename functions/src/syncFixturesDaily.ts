import * as functions from 'firebase-functions';

import { FifaSyncSummary, fifaSyncRanges, syncFifaMatches } from './fifaApi';

async function runFifaSync(): Promise<FifaSyncSummary> {
	const summary = { matchesSynced: 0, leaguesSynced: 0 };
	for (const range of fifaSyncRanges()) {
		const rangeSummary = await syncFifaMatches(range.from, range.to);
		summary.matchesSynced += rangeSummary.matchesSynced;
		summary.leaguesSynced += rangeSummary.leaguesSynced;
	}
	return summary;
}

export const syncFixturesDaily = functions
	.runWith({ timeoutSeconds: 540 })
	.pubsub
	.schedule('every 24 hours')
	.timeZone('America/Argentina/Buenos_Aires')
	.onRun(async () => {
		const summary = await runFifaSync();
		console.log(
			`Fixture sync complete. fifa=${summary.matchesSynced}, leagues=${summary.leaguesSynced}`,
		);
		return null;
	});

export const syncFixturesNow = functions.https.onCall(async (_data, context) => {
	if (context.auth?.token.admin !== true) {
		throw new functions.https.HttpsError(
			'permission-denied',
			'No tenes permisos de administrador',
		);
	}

	const summary = await runFifaSync();
	return { success: true, ...summary };
});

export const refreshLeagueCatalog = functions.https.onCall(
	async (_data, context) => {
		if (context.auth?.token.admin !== true) {
			throw new functions.https.HttpsError(
				'permission-denied',
				'No tenes permisos de administrador',
			);
		}

		const summary = await runFifaSync();
		return { success: true, ...summary };
	},
);
