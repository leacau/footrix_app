import * as admin from 'firebase-admin';

admin.initializeApp();

export { calculatePointsOnMatchFinish } from './calculatePointsOnMatchFinish';
export { validatePredictionEdit } from './validatePredictionEdit';
export { notifyOnPointsAssigned } from './notifyOnPointsAssigned';
export { notifyOnGroupInvite } from './notifyOnGroupInvite';
export { awardTriviaPoints } from './awardTriviaPoints';

