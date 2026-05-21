import { Firestore } from '@google-cloud/firestore';

async function seedLeagues() {
	const firestore = new Firestore({
		projectId: 'footrix-dc5a7',
	});

	const leagues = [
		{ id: 'WC', name: 'FIFA World Cup', shortName: 'WC', country: 'World', apiSource: 'football-data', apiLeagueCode: 'WC' },
		{ id: 'CL', name: 'UEFA Champions League', shortName: 'CL', country: 'Europe', apiSource: 'football-data', apiLeagueCode: 'CL' },
		{ id: 'BL1', name: 'Bundesliga', shortName: 'BL1', country: 'Germany', apiSource: 'football-data', apiLeagueCode: 'BL1' },
		{ id: 'DED', name: 'Eredivisie', shortName: 'DED', country: 'Netherlands', apiSource: 'football-data', apiLeagueCode: 'DED' },
		{ id: 'BSA', name: 'Campeonato Brasileiro Serie A', shortName: 'BSA', country: 'Brazil', apiSource: 'football-data', apiLeagueCode: 'BSA' },
		{ id: 'PD', name: 'Primera Division', shortName: 'PD', country: 'Spain', apiSource: 'football-data', apiLeagueCode: 'PD' },
		{ id: 'FL1', name: 'Ligue 1', shortName: 'FL1', country: 'France', apiSource: 'football-data', apiLeagueCode: 'FL1' },
		{ id: 'ELC', name: 'Championship', shortName: 'ELC', country: 'England', apiSource: 'football-data', apiLeagueCode: 'ELC' },
		{ id: 'PPL', name: 'Primeira Liga', shortName: 'PPL', country: 'Portugal', apiSource: 'football-data', apiLeagueCode: 'PPL' },
		{ id: 'EC', name: 'European Championship', shortName: 'EC', country: 'Europe', apiSource: 'football-data', apiLeagueCode: 'EC' },
		{ id: 'SA', name: 'Serie A', shortName: 'SA', country: 'Italy', apiSource: 'football-data', apiLeagueCode: 'SA' },
		{ id: 'PL', name: 'Premier League', shortName: 'PL', country: 'England', apiSource: 'football-data', apiLeagueCode: 'PL' },
		{ id: 'ARG', name: 'Argentinian Primera Division', shortName: 'Argentina', country: 'Argentina', apiSource: 'thesportsdb', apiLeagueId: '4406' },
	];

	console.log(`Cargando ${leagues.length} ligas en Firestore...`);

	try {
		const batch = firestore.batch();

		for (const league of leagues) {
			const docRef = firestore.collection('leagues').doc(league.id);
			batch.set(
				docRef,
				{
					...league,
					active: true,
					syncEnabled: true,
					updatedAt: new Date(),
				},
				{ merge: true },
			);
		}

		await batch.commit();
		console.log('Ligas cargadas correctamente.');
	} catch (error) {
		console.error('Error cargando ligas:', error);
		process.exit(1);
	}
}

seedLeagues();
