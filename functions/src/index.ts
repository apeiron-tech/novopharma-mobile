/* eslint-disable @typescript-eslint/no-explicit-any */
/* eslint-disable max-len */
import * as admin from "firebase-admin";

// Initialize the Firebase Admin SDK if not initialized
if (admin.apps.length === 0) {
    admin.initializeApp();
}

// Export notification functions
export {onNewTrainingCreated, onNewBadgeCreated, onNewGoalCreated, sendUserBadgeNotification, onUserGoalCompleted, sendReminderNotifications, onNewCustomNotificationCreated, processScheduledNotification, onFormationQuizUpdated} from "./notifications";

/**
 * DEPRECATED / DISABLED: Badge progress processing is now handled by novopharma-back (salesTriggers.ts)
 * to avoid duplicate increments, support both pending and approved badge tracking, and align with goal tracking.
 */
/*
export const processSaleForBadgeAwards = onDocumentUpdated({
  region: "europe-west1",
  document: "sales/{saleId}",
}, async (event) => {
  ...
});
*/

/**
 * DEPRECATED / DISABLED: Goal progress processing is now handled by novopharma-back (salesTriggers.ts)
 * to avoid duplicate increments and to support both pending and approved goal tracking.
 */
/*
export const processSaleForGoalProgress = onDocumentUpdated("sales/{saleId}", async (event) => {
  ...
});
*/
