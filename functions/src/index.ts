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
	recalculateWorldCupScores,
	recalculateWorldCupScoresOnResult,
	refreshMyWorldCupScore,
	saveWorldCupPredictions,
	getWorldCupMatchPredictions,
} from './worldCupActions';
export {
	adminDeletePredictions,
	adminListPredictions,
	adminUpdatePrediction,
	adminUpdatePredictionPermissions,
	adminUpdateUserPoints,
} from './adminPredictionActions';
export {
	adminCreateMatch,
	adminFinishMatch,
	adminRepairUserDocuments,
	adminSyncAndRecalculateRecentPoints,
	adminToggleUserStatus,
	adminUpdatePredictionSettings,
} from './adminActions';

// ==========================================
// Sync con FIFA
// ==========================================
export { syncFixturesDaily } from './syncFixturesDaily';
export { syncFixturesNow, refreshLeagueCatalog } from './syncFixturesDaily';
export { pollMatchResults } from './pollMatchResults';
export {
	notifyOnMatchGoal,
	sendUpcomingMatchReminders,
} from './matchNotifications';

// ==========================================
// Función de salud para debug (con tipos explícitos)
// ==========================================
export const healthCheck = functions.https.onRequest(
	(req: Request, res: Response) => {
		res.json({ status: 'ok', timestamp: new Date().toISOString() });
	},
);
