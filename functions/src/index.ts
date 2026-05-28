import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions'; // ✅ IMPORTANTE: Agregar este import

import { Request, Response } from 'express'; // ✅ Para tipos explícitos

admin.initializeApp();

// ==========================================
// Funciones existentes
// ==========================================
export { calculatePointsOnMatchFinish } from './calculatePointsOnMatchFinish';
export { validatePredictionEdit } from './validatePredictionEdit';
export { notifyOnPointsAssigned } from './notifyOnPointsAssigned';
export { notifyOnGroupInvite } from './notifyOnGroupInvite';
export { awardTriviaPoints } from './awardTriviaPoints';
export { getTriviaQuestions, submitTriviaAnswer } from './triviaActions';
export {
	createGroup,
	deleteGroup,
	getGroupPredictions,
	joinGroup,
	leaveGroup,
	removeGroupMember,
} from './groupActions';
export { remindAnonymousUsersToCompleteProfile } from './anonymousProfileReminder';
export { getRankingPredictionCounts } from './rankingActions';
export {
	adminCreateMatch,
	adminFinishMatch,
	adminSyncAndRecalculateRecentPoints,
	adminToggleUserStatus,
	adminUpdatePredictionSettings,
	adminUpdateTriviaSettings,
} from './adminActions';

// ==========================================
// Sync con FIFA
// ==========================================
export { syncFixturesDaily } from './syncFixturesDaily';
export { syncFixturesNow, refreshLeagueCatalog } from './syncFixturesDaily';
export { pollMatchResults } from './pollMatchResults';

// ==========================================
// Función de salud para debug (con tipos explícitos)
// ==========================================
export const healthCheck = functions.https.onRequest(
	(req: Request, res: Response) => {
		res.json({ status: 'ok', timestamp: new Date().toISOString() });
	},
);
