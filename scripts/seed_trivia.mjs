import { Firestore } from '@google-cloud/firestore';

async function seedTrivia() {
	const projectId = 'footrix-dc5a7'; // Tu ID de proyecto de Firebase

	// Inicialización simplificada (evita conflictos de versiones de auth)
	const firestore = new Firestore({
		projectId,
	});

	const triviaQuestions = [
		{
			question: '¿Quién ganó el Mundial de Fútbol 2022?',
			options: ['Brasil', 'Francia', 'Argentina', 'Alemania'],
			correctAnswer: 2,
			category: 'mundial',
			points: 1,
			active: true,
		},
		{
			question: '¿Cuántos Balones de Oro tiene Lionel Messi?',
			options: ['6', '7', '8', '9'],
			correctAnswer: 2,
			category: 'jugadores',
			points: 1,
			active: true,
		},
		{
			question: '¿En qué año se fundó la FIFA?',
			options: ['1904', '1920', '1930', '1950'],
			correctAnswer: 0,
			category: 'historia',
			points: 1,
			active: true,
		},
		{
			question: '¿Qué país ganó más Copas del Mundo?',
			options: ['Alemania', 'Italia', 'Argentina', 'Brasil'],
			correctAnswer: 3,
			category: 'mundial',
			points: 1,
			active: true,
		},
		{
			question:
				'¿Quién es el máximo goleador de la historia de la Champions League?',
			options: ['Raúl', 'Lewandowski', 'Cristiano Ronaldo', 'Messi'],
			correctAnswer: 2,
			category: 'jugadores',
			points: 1,
			active: true,
		},
		{
			question: '¿En qué país se jugó el primer Mundial de Fútbol?',
			options: ['Italia', 'Uruguay', 'Brasil', 'Francia'],
			correctAnswer: 1,
			category: 'historia',
			points: 1,
			active: true,
		},
		{
			question: '¿Qué equipo tiene más títulos de Champions League?',
			options: ['Barcelona', 'Bayern Múnich', 'Real Madrid', 'Milan'],
			correctAnswer: 2,
			category: 'equipos',
			points: 1,
			active: true,
		},
		{
			question: '¿Quién ganó la Copa América 2021?',
			options: ['Brasil', 'Colombia', 'Argentina', 'Uruguay'],
			correctAnswer: 2,
			category: 'copa_america',
			points: 1,
			active: true,
		},
		{
			question: '¿Cuántos jugadores hay en un equipo de fútbol en la cancha?',
			options: ['9', '10', '11', '12'],
			correctAnswer: 2,
			category: 'reglas',
			points: 1,
			active: true,
		},
		{
			question: "¿Qué significa 'hat-trick' en fútbol?",
			options: [
				'3 asistencias',
				'3 goles en un partido',
				'3 tarjetas amarillas',
				'3 penales atajados',
			],
			correctAnswer: 1,
			category: 'reglas',
			points: 1,
			active: true,
		},
	];

	console.log('🌱 Sembrando preguntas de trivia...');

	try {
		const batch = firestore.batch();

		triviaQuestions.forEach((q, i) => {
			const docRef = firestore
				.collection('triviaQuestions')
				.doc(`question_${i + 1}`);

			batch.set(docRef, {
				...q,
			});
		});

		await batch.commit();
		console.log(
			'✅ ¡Éxito! Las preguntas de trivia han sido cargadas correctamente.',
		);
	} catch (error) {
		console.error('❌ Error cargando preguntas de trivia:', error);
		process.exit(1);
	}
}

seedTrivia();
