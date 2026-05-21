import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

// ❌ NO agregar admin.initializeApp() aquí - ya está en index.ts

export const awardTriviaPoints = functions.firestore
	.document('trivia_answers/{answerId}')
	.onCreate(async (snap, context) => {
		const answer = snap.data();
		if (answer.serverAwarded === true) {
			console.log(`Trivia ${context.params.answerId} already awarded by callable`);
			return null;
		}

		const userId = answer.userId as string;
		const questionId = answer.questionId as string;
		const isCorrect = answer.isCorrect as boolean;
		const basePoints = (answer.pointsEarned as number) ?? 0;

		// Obtener pregunta para categoría
		const questionDoc = await admin
			.firestore()
			.collection('trivia_questions')
			.doc(questionId)
			.get();

		if (!questionDoc.exists) {
			console.log(`⚠️ Pregunta ${questionId} no encontrada`);
			return null;
		}

		const category = (questionDoc.data()?.category as string) ?? 'general';

		// Calcular racha y bonus
		const userDoc = await admin
			.firestore()
			.collection('users')
			.doc(userId)
			.get();

		const userData = userDoc.data() ?? {};
		const currentStreak = (userData.triviaStreak as number) ?? 0;
		const bestStreak = (userData.triviaBestStreak as number) ?? 0;

		// Bonus: +1 punto por cada 3 aciertos seguidos
		let bonusPoints = 0;
		if (isCorrect && currentStreak > 0 && currentStreak % 3 === 0) {
			bonusPoints = 1;
			console.log(`🔥 Bonus por racha: ${userId} en ${currentStreak} aciertos`);
		}

		const totalPoints = basePoints + bonusPoints;
		const newBestStreak =
			currentStreak > bestStreak ? currentStreak : bestStreak;

		// Actualizar usuario
		await admin
			.firestore()
			.collection('users')
			.doc(userId)
			.update({
				triviaPoints: admin.firestore.FieldValue.increment(totalPoints),
				triviaStreak: isCorrect ? currentStreak + 1 : 0,
				triviaBestStreak: newBestStreak,
				triviaAnswered: admin.firestore.FieldValue.increment(1),
				[`triviaByCategory.${category}`]: admin.firestore.FieldValue.increment(
					isCorrect ? 1 : 0,
				),
				updatedAt: admin.firestore.FieldValue.serverTimestamp(),
			});

		console.log(
			`✅ Trivia: ${userId} ganó ${totalPoints} pts (base: ${basePoints}, bonus: ${bonusPoints})`,
		);

		return null;
	});
