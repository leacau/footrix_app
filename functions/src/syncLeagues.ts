import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

const API_KEY = functions.config().apifootball?.key;
const API_HOST = 'v3.football.api-sports.io';

export const syncLeagues = functions.https.onRequest(async (req, res) => {
	if (!API_KEY) {
		res.status(500).json({ error: 'API key not configured' });
		return;
	}

	try {
		const response = await fetch('https://v3.football.api-sports.io/leagues', {
			headers: {
				'x-rapidapi-key': API_KEY,
				'x-rapidapi-host': API_HOST,
			},
		});

		if (!response.ok) {
			throw new Error(`API error: ${response.status}`);
		}

		const data = await response.json();
		const db = admin.firestore();
		let synced = 0;

		for (const item of data.response) {
			const leagueId = `api_${item.league.id}`;
			await db
				.collection('leagues')
				.doc(leagueId)
				.set(
					{
						name: item.league.name,
						shortName: item.league.name,
						country: item.country.name,
						logo: item.league.logo,
						apiFootballId: item.league.id,
						active: true,
						currentSeason: item.seasons?.[item.seasons.length - 1]?.year,
						updatedAt: admin.firestore.FieldValue.serverTimestamp(),
					},
					{ merge: true },
				);
			synced++;
		}

		res.json({ success: true, synced, total: data.response.length });
	} catch (error) {
		console.error('Error syncing leagues:', error);
		res.status(500).json({ error: 'Sync failed' });
	}
});
