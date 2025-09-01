# NovoPharma Project Documentation

This file is maintained by your Gemini assistant to document the project's architecture, features, and key implementation details as they are discovered.

## 1. Project Overview

- **Framework:** Flutter
- **Backend:** Firebase (Authentication, Cloud Firestore)
- **State Management:** `provider` package

## 2. Architecture & Navigation

The application follows a clean, service-based architecture and uses a primary `SharedBottomNavigationBar` for main screen navigation.

- **Services (`lib/services/`):** Handle direct communication with the backend (Firestore).
- **Providers/Controllers (`lib/controllers/`):** Bridge the UI and services, manage state.
- **Models (`lib/models/`):** Define data structures.
- **Screens (`lib/screens/`):** The UI layer.

### 2.1. Navigation Flow

- **Main Navigation:** A custom bottom navigation bar (`SharedBottomNavigationBar`) provides access to Home, Challenges, Leaderboard, and Sales History.
- **Profile Access:** The user's `ProfileScreen` is now accessed via an icon button in the header of the `DashboardHomeScreen`.
- **Scan Flow:** The scan flow is initiated by a central Floating Action Button (FAB) and navigates the user to the `BarcodeScannerScreen` and then the `ProductScreen`.

## 3. Features & Implementation Notes

### 3.1. Rewards System

- **Functionality:** Allows users to redeem rewards using points. Includes a history view.
- **Redemption Logic:** The `RedeemedRewardService` uses an atomic Firestore transaction to create a `redeemedRewards` record, decrement user points, and decrement reward stock.
- **State Management:** `RewardsController` fetches reward data and the user's redemption history.
- **UI:** The `RewardsScreen` displays available rewards (with stock counts) and the user's real-time point balance. The `RewardHistoryScreen` lists all past redemptions.

### 3.2. Leaderboard

- **Functionality:** Displays a ranked list of users based on points earned over different time periods.
- **Data Fetching:** `LeaderboardService` queries the `sales` collection and aggregates points per user.
- **State Management:** `LeaderboardProvider` manages the state and the selected time filter.

### 3.3. Scan Flow & Stock Management

- **Functionality:** Allows users to scan products, adjust quantity, see related promotions, and confirm a sale while respecting product stock.
- **Implementation:**
    1.  **Scan & Lookup:** `BarcodeScannerScreen` captures the SKU and pushes to `ProductScreen`, which uses `ScanProvider` to fetch product data, campaigns, goals, and recommended products.
    2.  **UI & State:** The `ProductScreen` displays all fetched data, including available stock. The quantity selector is limited by available stock, and the confirm button is disabled if the product is out of stock.
    3.  **Sale Confirmation (Atomic Transaction):** `SaleService.createSale()` runs a transaction that verifies stock before creating the `sales` document, incrementing user `points`, and decrementing product `stock`.

### 3.4. Real-Time Point Updates

- **Functionality:** A user's total points on the `DashboardHomeScreen` and `RewardsScreen` update in real-time after a sale or redemption.
- **Implementation:** `UserService.getUserProfile` was converted from a `Future` to a `Stream`. The `AuthProvider` subscribes to this stream, receiving and propagating real-time updates to the user's profile to all listening widgets.

## 4. Database Schema

*The following schema was provided by the user.*

### `users`
- **id:** Firebase Auth UID
- **fields:** name, email, avatarUrl, dateOfBirth, phone, role, pharmacy (label), pharmacyId, points (number), status ("pending" | "active" | "disabled"), createdAt, updatedAt

### `pharmacies`
- **fields:** name, email, phone, address, city, postalCode, zone, clientCategory, location (lat/lng), createdAt, updatedAt

### `products`
- **fields:** name, marque (brand), category, description, price (number), points (reward points), sku, stock, protocol (text), recommendedWith (array of productIds), createdAt, updatedAt

### `sales`
- **fields:** userId, pharmacyId, productId, productNameSnapshot, quantity (number), pointsEarned (number), saleDate (timestamp)

### `rewards`
- **fields:** name, description, imageUrl, pointsCost (number), stock (number), dataAiHint (string), createdAt, updatedAt

### `redeemedRewards`
- **fields:** userId, userNameSnapshot, rewardId, rewardNameSnapshot, pointsSpent (number), createdAt (timestamp), redeemedAt (timestamp)

### `user_badges`
- **fields:** userId, badgeId, badgeName, badgeDescription, badgeImageUrl, context, awardedAt (timestamp)

### `quizzes`
- **fields:** title, type ("regular"), active (bool), attemptLimit (number), points (number), quizTimeLimitSeconds (number), startDate, endDate, createdAt, updatedAt
- **questions:** array of objects { text, options [string], correctAnswers [index], explanation (string), multipleAnswersAllowed (bool), timeLimitSeconds (number) }

### `goals`
- **fields:** title, description, isActive (bool), metric (e.g., "quantity", "revenue"), targetValue (number), rewardPoints (number), criteria (object of multi-select filters), startDate, endDate, createdAt, updatedAt

### `campaigns`
- **fields:** title, description, coverImageUrl, videoUrl (optional), productCriteria (filters), tradeOfferProductIds [string], linkedGoalId (string), startDate, endDate, createdAt, updatedAt

## 5. Account Approval Flow

1.  **Sign-up:** A Firebase Auth user is created, and a corresponding document is added to the `users` collection with `status="pending"`.
2.  **Pending Status:** While the user's status is "pending", they are shown a "Pending Approval" screen and cannot access the main application.
3.  **Approval:** An administrator changes the user's status to "active" in Firestore. The user can then sign in and access the app.
4.  **Disabled:** If the status is changed to "disabled", the user is denied access.