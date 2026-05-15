import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

const API_KEY = functions.config().apifootball?.key;
const API_HOST = 'v3.football.api-sports.io';

export const syncFixtures = functions.https.onCall(async (data, context) => {
	if (!context.auth) {
		throw new functions.https.HttpsError('unauthenticated', 'No autenticado');
	}

	const { leagueId, season, daysAhead = 7 } = data;

	if (!API_KEY) {
		throw new functions.https.HttpsError('internal', 'API key not configured');
	}

	try {
		const dateFrom = new Date().toISOString().split('T')[0];
		const dateTo = new Date(Date.now() + daysAhead * 24 * 60 * 60 * 1000)
			.toISOString()
			.split('T')[0];

		const response = await fetch(
			`https://v3.football.api-sports.io/fixtures?league=${leagueId}&season=${season}&from=${dateFrom}&to=${dateTo}`,
			{
				headers: {
					'x-rapidapi-key': API_KEY,
					'x-rapidapi-host': API_HOST,
				},
			},
		);

		if (!response.ok) {
			throw new Error(`API error: ${response.status}`);
		}

		const apiData = await response.json();
		const db = admin.firestore();
		let synced = 0;

		for (const fixture of apiData.response) {
			const matchId = `api_${fixture.fixture.id}`;

			const matchData = {
				homeTeam: fixture.teams.home.name,
				awayTeam: fixture.teams.away.name,
				kickoff: admin.firestore.Timestamp.fromMillis(
					fixture.fixture.timestamp * 1000,
				),
				status: mapStatus(fixture.fixture.status.short),
				homeScore: fixture.goals.home ?? null,
				awayScore: fixture.goals.away ?? null,
				leagueId: `api_${leagueId}`,
				apiFootballMatchId: fixture.fixture.id,
				phase: fixture.league.round,
				venue: fixture.fixture.venue?.name,
				lockHoursBefore: 12, // Default, configurable later
				updatedAt: admin.firestore.FieldValue.serverTimestamp(),
			};

			await db
				.collection('matches')
				.doc(matchId)
				.set(matchData, { merge: true });
			synced++;
		}

		return { success: true, synced, total: apiData.response.length };
	} catch (error) {
		console.error('Error syncing fixtures:', error);
		throw new functions.https.HttpsError('internal', 'Sync failed');
	}
});

// Helper para mapear estados
function mapStatus(apiStatus: string): string {
	const statusMap: Record<string, string> = {
		NS: 'scheduled',
		'1H': 'live',
		'2H': 'live',
		HT: 'halftime',
		FT: 'finished',
		AET: 'finished',
		PEN: 'finished',
		PST: 'postponed',
		CANC: 'cancelled',
	};
	return statusMap[apiStatus] ?? 'scheduled';
}
