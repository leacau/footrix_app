import { Firestore } from '@google-cloud/firestore';

/**
 * Script para cargar partidos iniciales en Firestore
 * Asegúrate de estar logueado en la terminal con:
 * firebase login  O  gcloud auth application-default login
 */

async function seedMatches() {
	const projectId = 'footrix-dc5a7'; // Tu ID de proyecto de Firebase

	// Inicialización simplificada (evita conflictos de versiones de auth)
	const firestore = new Firestore({
		projectId,
	});

	const matches = [
		{
			home: 'Argentina',
			away: 'Arabia Saudita',
			phase: 'Grupo A',
			kickoff: '2026-06-11T15:00:00Z',
		},
		{
			home: 'México',
			away: 'Sudáfrica',
			phase: 'Grupo A',
			kickoff: '2026-06-11T18:00:00Z',
		},
		{
			home: 'España',
			away: 'Estados Unidos',
			phase: 'Grupo B',
			kickoff: '2026-06-12T15:00:00Z',
		},
		{
			home: 'Nigeria',
			away: 'Canadá',
			phase: 'Grupo B',
			kickoff: '2026-06-12T18:00:00Z',
		},
		{
			home: 'Brasil',
			away: 'Camerún',
			phase: 'Grupo C',
			kickoff: '2026-06-13T15:00:00Z',
		},
		{
			home: 'Francia',
			away: 'Japón',
			phase: 'Grupo C',
			kickoff: '2026-06-13T18:00:00Z',
		},
		{
			home: 'Alemania',
			away: 'Corea del Sur',
			phase: 'Grupo D',
			kickoff: '2026-06-14T15:00:00Z',
		},
		{
			home: 'Inglaterra',
			away: 'Colombia',
			phase: 'Grupo D',
			kickoff: '2026-06-14T18:00:00Z',
		},
		{
			home: 'Uruguay',
			away: 'Egipto',
			phase: 'Grupo E',
			kickoff: '2026-06-15T15:00:00Z',
		},
		{
			home: 'Italia',
			away: 'Australia',
			phase: 'Grupo E',
			kickoff: '2026-06-15T18:00:00Z',
		},
	];

	console.log('📦 Iniciando carga de 10 partidos en Firestore...');

	try {
		const batch = firestore.batch();

		matches.forEach((m, i) => {
			const docRef = firestore.collection('matches').doc(`match_${i + 1}`);

			batch.set(docRef, {
				homeTeam: m.home,
				awayTeam: m.away,
				phase: m.phase,
				// LA CORRECCIÓN: Convertimos el string a un objeto Date
				kickoff: new Date(m.kickoff),
				status: 'scheduled',
				homeScore: null,
				awayScore: null,
				homeYellowCards: 0,
				awayYellowCards: 0,
				hasPenalties: false,
				createdAt: new Date(), // También para la fecha de creación
			});
		});

		await batch.commit();
		console.log('✅ ¡Éxito! Los 10 partidos han sido cargados correctamente.');
	} catch (error) {
		console.error('❌ Error cargando partidos:', error);
		process.exit(1);
	}
}

// Ejecutar la función
seedMatches();
