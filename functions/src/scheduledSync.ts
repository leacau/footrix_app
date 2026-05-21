import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

import { THESPORTSDB_BASE_URL } from './config';

// Helper para mapear estados de TheSportsDB
function mapTheSportsDBStatus(apiStatus: string | null | undefined): string {
	if (!apiStatus) return 'scheduled';

	const statusMap: Record<string, string> = {
		'Not Started': 'scheduled',
		'1H': 'live',
		HT: 'halftime',
		'2H': 'live',
		FT: 'finished',
		AET: 'finished',
		PEN: 'finished',
		Postponed: 'postponed',
		Cancelled: 'cancelled',
		Abandoned: 'cancelled',
		Interrupted: 'postponed',
		Suspended: 'postponed',
	};
	return statusMap[apiStatus] ?? 'scheduled';
}

// ✅ Función auxiliar reutilizable para sync de fixtures
async function syncFixturesForLeague(
	apiLeagueId: string,
	internalLeagueId: string,
) {
	const db = admin.firestore();
	const baseUrl = THESPORTSDB_BASE_URL.value();
	const season = new Date().getFullYear();

	try {
		const url = `${baseUrl}/events_season.php?id=${apiLeagueId}&s=${season}`;
		const response = await fetch(url);

		if (!response.ok) {
			throw new Error(`API error: ${response.status}`);
		}

		const data = await response.json();
		const events = data.events || [];
		let synced = 0;

		for (const event of events) {
			const matchId = `tsdb_${event.idEvent}`;

			const matchData = {
				homeTeam: event.strHomeTeam,
				awayTeam: event.strAwayTeam,
				kickoff:
					event.dateEvent && event.strTime
						? admin.firestore.Timestamp.fromDate(
								new Date(`${event.dateEvent}T${event.strTime}:00Z`),
							)
						: null,
				status: mapTheSportsDBStatus(event.strStatus),
				homeScore: event.intHomeScore ? parseInt(event.intHomeScore) : null,
				awayScore: event.intAwayScore ? parseInt(event.intAwayScore) : null,
				leagueId: internalLeagueId,
				apiSource: 'thesportsdb',
				apiMatchId: event.idEvent,
				venue: event.strVenue,
				round: event.strRound,
				updatedAt: admin.firestore.FieldValue.serverTimestamp(),
				syncedAt: admin.firestore.FieldValue.serverTimestamp(),
			};

			await db
				.collection('matches')
				.doc(matchId)
				.set(matchData, { merge: true });
			synced++;
		}

		return { synced, total: events.length };
	} catch (error) {
		console.error(`❌ Error syncing league ${internalLeagueId}:`, error);
		throw error;
	}
}

// ✅ Scheduled Function: Sync diario de fixtures
export const scheduledFixtureSync = functions.pubsub
	.schedule('every 24 hours')
	.timeZone('America/Argentina/Buenos_Aires')
	.onRun(async () => {
		const db = admin.firestore();
		let totalSynced = 0;

		// ✅ CORRECCIÓN: Sintaxis correcta de .where() con operadores posicionales
		const leaguesSnap = await db
			.collection('leagues')
			.where('active', '==', true) // ✅ Correcto: '==', no isEqualTo:
			.where('syncEnabled', '==', true) // ✅ Solo ligas con sync habilitado
			.get();

		for (const leagueDoc of leaguesSnap.docs) {
			const league = leagueDoc.data();
			const apiLeagueId = league.apiLeagueId;
			const internalLeagueId = leagueDoc.id;

			if (!apiLeagueId) continue;

			try {
				const result = await syncFixturesForLeague(
					apiLeagueId,
					internalLeagueId,
				);
				totalSynced += result.synced;
				console.log(
					`✅ Synced ${result.synced} fixtures for league ${league.name}`,
				);
			} catch (error) {
				console.error(`❌ Error syncing league ${league.name}:`, error);
			}
		}

		console.log(`🎉 Scheduled sync complete: ${totalSynced} fixtures synced`);
		return null;
	});
