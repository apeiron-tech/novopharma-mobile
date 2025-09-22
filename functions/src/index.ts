/* eslint-disable @typescript-eslint/no-explicit-any */
/* eslint-disable max-len */
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

// Initialize the Firebase Admin SDK to interact with Firestore
admin.initializeApp();
const db = admin.firestore();

/**
 * This Cloud Function is the heart of the goal-tracking system.
 * It automatically triggers whenever a new document is created in the 'sales' collection.
 *
 * Here's the process:
 * 1. When a sale is recorded, the function activates.
 * 2. It fetches all currently active goals from the 'goals' collection.
 * 3. It retrieves the details of the user and their associated pharmacy.
 * 4. For each active goal, it checks if the sale meets the specific eligibility criteria.
 * 5. If eligible, it checks the goal's 'metric' ('revenue' or 'quantity').
 * 6. It updates the user's progress in the 'users/{userId}/userGoalProgress' subcollection
 *    using the correct value from the sale (either 'totalPrice' or 'quantity').
 * 7. If the user's progress meets or exceeds the goal's target, the function marks the goal
 *    as 'completed' for that user and awards them the specified reward points.
 * 8. All operations include detailed logging for easier debugging.
 */
export const processSaleForGoalProgress = onDocumentCreated("sales/{saleId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    logger.error("No data associated with the event.");
    return;
  }

  const sale = snapshot.data();
  const {userId, pharmacyId, productId, quantity, totalPrice} = sale;
  const {saleId} = event.params;

  // Basic validation
  if (!userId) {
    logger.error(`Sale document ${saleId} is missing a userId.`);
    return;
  }

  try {
    // Fetch all necessary data in parallel for efficiency
    const [
      activeGoalsSnapshot,
      userDoc,
      productDoc,
    ] = await Promise.all([
      db.collection("goals").where("isActive", "==", true).get(),
      db.collection("users").doc(userId).get(),
      db.collection("products").doc(productId).get(),
    ]);

    if (activeGoalsSnapshot.empty) {
      logger.info("No active goals found. Exiting.");
      return;
    }

    if (!userDoc.exists) {
      logger.error(`User with ID ${userId} not found.`);
      return;
    }
    const user = userDoc.data();

    // Fetch pharmacy details
    const pharmacyDoc = await db.collection("pharmacies").doc(pharmacyId).get();
    const pharmacy = pharmacyDoc.exists ? pharmacyDoc.data() : undefined;

    if (!productDoc.exists) {
      logger.error(`Product with ID ${productId} not found.`);
      return;
    }
    const product = productDoc.data();

    // Process each goal against the sale
    for (const goalDoc of activeGoalsSnapshot.docs) {
      const goal = goalDoc.data();
      const goalId = goalDoc.id;

      const isEligible = isSaleEligible(sale, goal, user, pharmacy, product);

      if (isEligible) {
        const userProgressRef = db.collection("users").doc(userId)
          .collection("userGoalProgress").doc(goalId);
        const progressDoc = await userProgressRef.get();

        // Skip if goal is already completed for this user
        if (progressDoc.exists && progressDoc.data()?.status === "completed") {
          logger.info(`User ${userId} has already completed goal ${goalId}. Skipping.`);
          continue;
        }

        // Determine the value to increment based on the goal's metric
        const incrementValue = goal.metric === "revenue" ? totalPrice : quantity;

        const currentProgress = progressDoc.exists ? progressDoc.data()?.progressValue : 0;
        const newProgress = currentProgress + incrementValue;

        // Update progress
        await userProgressRef.set({
          progressValue: newProgress,
          status: "in-progress",
        }, {merge: true});

        logger.info(`Updated progress for user ${userId} on goal ${goalId}. New progress: ${newProgress}`);

        // Check for goal completion
        if (newProgress >= goal.targetValue) {
          await userProgressRef.update({status: "completed"});

          // Award points to the user
          await db.collection("users").doc(userId).update({
            points: admin.firestore.FieldValue.increment(goal.rewardPoints),
          });

          logger.info(`Goal ${goalId} completed for user ${userId}! Awarded ${goal.rewardPoints} points.`);
        }
      }
    }
  } catch (error) {
    logger.error(`Failed to process sale ${saleId} for goal tracking.`, {error});
  }
});

/**
 * Checks if a sale is eligible for a given goal based on its criteria.
 * @param {any} sale The sale document data.
 * @param {any} goal The goal document data.
 * @param {any} user The user document data.
 * @param {any} pharmacy The pharmacy document data.
 * @param {any} product The product document data.
 * @return {boolean} True if the sale is eligible, false otherwise.
 */
function isSaleEligible(sale: any, goal: any, user: any, pharmacy: any, product: any): boolean {
  const {criteria} = goal;
  if (!criteria) return true; // No criteria means eligible for all

  // Check product-related criteria
  if (criteria.products?.length > 0 && !criteria.products.includes(sale.productId)) return false;
  if (criteria.brands?.length > 0 && !criteria.brands.includes(product?.marque)) return false;
  if (criteria.categories?.length > 0 && !criteria.categories.includes(product?.category)) return false;

  // Check pharmacy-related criteria
  if (criteria.pharmacyIds?.length > 0 && !criteria.pharmacyIds.includes(user?.pharmacyId)) return false;
  if (criteria.zones?.length > 0 && !criteria.zones.includes(pharmacy?.zone)) return false;
  if (criteria.clientCategories?.length > 0 && !criteria.clientCategories.includes(pharmacy?.clientCategory)) return false;

  return true; // If no checks failed, the sale is eligible
}
