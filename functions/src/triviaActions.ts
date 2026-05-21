import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

function requireAuth(context: functions.https.CallableContext): string {
	if (!context.auth) {
		throw new functions.https.HttpsError('unauthenticated', 'No autenticado');
	}
	return context.auth.uid;
}

function parseOption(value: unknown): number {
	if (!Number.isInteger(value) || (value as number) < 0 || (value as number) > 3) {
		throw new functions.https.HttpsError(
			'invalid-argument',
			'Opcion invalida',
		);
	}
	return value as number;
}

export const getTriviaQuestions = functions.https.onCall(
	async (_data, context) => {
		requireAuth(context);

		let snap = await admin
			.firestore()
			.collection('trivia_questions')
			.where('active', '==', true)
			.orderBy('createdAt', 'desc')
			.limit(50)
			.get();

		if (snap.empty) {
			snap = await admin
				.firestore()
				.collection('triviaQuestions')
				.where('active', '==', true)
				.limit(50)
				.get();
		}

		return {
			questions: snap.docs.map((doc) => {
				const data = doc.data();
				return {
					id: doc.id,
					question: data.question ?? '',
					options: Array.isArray(data.options) ? data.options : [],
					category: data.category ?? 'general',
					points: typeof data.points === 'number' ? data.points : 1,
					active: data.active === true,
					createdAt:
						data.createdAt instanceof admin.firestore.Timestamp
							? data.createdAt.toMillis()
							: null,
				};
			}),
		};
	},
);

export const submitTriviaAnswer = functions.https.onCall(
	async (data, context) => {
		const uid = requireAuth(context);
		const questionId = typeof data.questionId === 'string' ? data.questionId : '';
		const selectedOption = parseOption(data.selectedOption);

		if (!questionId.trim()) {
			throw new functions.https.HttpsError(
				'invalid-argument',
				'Pregunta invalida',
			);
		}

		const db = admin.firestore();
		const cleanQuestionId = questionId.trim();
		const questionRef = db.collection('trivia_questions').doc(cleanQuestionId);
		const userRef = db.collection('users').doc(uid);
		const answerRef = db
			.collection('trivia_answers')
			.doc(`${uid}_${cleanQuestionId}`);

		return db.runTransaction(async (tx) => {
			const questionDoc = await tx.get(questionRef);
			const answerDoc = await tx.get(answerRef);
			const userDoc = await tx.get(userRef);

			if (!questionDoc.exists) {
				throw new functions.https.HttpsError(
					'not-found',
					'Pregunta no encontrada',
				);
			}

			const question = questionDoc.data()!;
			if (question.active !== true) {
				throw new functions.https.HttpsError(
					'failed-precondition',
					'La pregunta ya no esta activa',
				);
			}

			const correctAnswer = question.correctAnswer;
			if (!Number.isInteger(correctAnswer) || correctAnswer < 0 || correctAnswer > 3) {
				throw new functions.https.HttpsError(
					'internal',
					'Pregunta mal configurada',
				);
			}

			if (answerDoc.exists) {
				const existing = answerDoc.data()!;
				return {
					success: true,
					alreadyAnswered: true,
					isCorrect: existing.isCorrect === true,
					pointsEarned:
						typeof existing.pointsEarned === 'number'
							? existing.pointsEarned
							: 0,
					correctAnswer,
					streak:
						typeof existing.streakAtAnswer === 'number'
							? existing.streakAtAnswer
							: 0,
				};
			}

			const userData = userDoc.data() ?? {};
			const currentStreak =
				typeof userData.triviaStreak === 'number' ? userData.triviaStreak : 0;
			const bestStreak =
				typeof userData.triviaBestStreak === 'number'
					? userData.triviaBestStreak
					: 0;

			const isCorrect = selectedOption === correctAnswer;
			const newStreak = isCorrect ? currentStreak + 1 : 0;
			const basePoints =
				isCorrect && typeof question.points === 'number' ? question.points : 0;
			const bonusPoints = isCorrect && newStreak % 3 === 0 ? 1 : 0;
			const pointsEarned = basePoints + bonusPoints;
			const category =
				typeof question.category === 'string' ? question.category : 'general';

			tx.set(answerRef, {
				userId: uid,
				questionId: cleanQuestionId,
				selectedOption,
				isCorrect,
				pointsEarned,
				streakAtAnswer: newStreak,
				serverAwarded: true,
				answeredAt: admin.firestore.FieldValue.serverTimestamp(),
			});

			tx.set(
				userRef,
				{
					triviaPoints: admin.firestore.FieldValue.increment(pointsEarned),
					triviaStreak: newStreak,
					triviaBestStreak: Math.max(bestStreak, newStreak),
					triviaAnswered: admin.firestore.FieldValue.increment(1),
					[`triviaByCategory.${category}`]:
						admin.firestore.FieldValue.increment(isCorrect ? 1 : 0),
					updatedAt: admin.firestore.FieldValue.serverTimestamp(),
				},
				{ merge: true },
			);

			return {
				success: true,
				alreadyAnswered: false,
				isCorrect,
				pointsEarned,
				correctAnswer,
				streak: newStreak,
			};
		});
	},
);
