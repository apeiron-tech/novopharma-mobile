This app is a gamified rewards and engagement platform for pharmacy employees. It allows them to earn points, compete on leaderboards, and redeem rewards by tracking sales and participating in quizzes and goals.

### Features

-   **Authentication**: Users can sign up, log in, and manage their passwords. New accounts require admin approval.
    -   *Files*: `lib/screens/login_screen.dart`, `lib/screens/signup_screen.dart`, `lib/services/auth_service.dart`
-   **Dashboard**: Displays total points, daily stats, and quick access to other features.
    -   *Files*: `lib/screens/dashboard_home_screen.dart`
-   **Barcode Scanning**: Users can scan product barcodes to view details and log sales.
    -   *Files*: `lib/screens/barcode_scanner_screen.dart`, `lib/screens/product_screen.dart`
-   **Goals & Challenges**: Users can view and track progress towards sales or engagement goals.
    -   *Files*: `lib/screens/goals_screen.dart`, `lib/services/goal_service.dart`
-   **Leaderboard**: A competitive leaderboard ranks users daily, weekly, monthly, or yearly based on points.
    -   *Files*: `lib/screens/leaderboard_screen.dart`, `lib/services/leaderboard_service.dart`
-   **Quizzes**: Users can take quizzes to earn points.
    -   *Files*: `lib/screens/quiz_list_screen.dart`, `lib/screens/quiz_question_screen.dart`, `lib/services/quiz_service.dart`
-   **Rewards**: Users can redeem earned points for rewards.
    -   *Files*: `lib/screens/rewards_screen.dart`, `lib/services/rewards_service.dart`
-   **Profile Management**: Users can view and update their profile information.
    -   *Files*: `lib/screens/profile_screen.dart`, `lib/services/user_service.dart`

### Navigation

-   **Start Screen**: The app starts with `AuthWrapper` (`lib/screens/auth_wrapper.dart`), which directs users to the `LoginScreen` or `DashboardHomeScreen` based on their authentication state.
-   **Main Routes**:
    -   `/dashboard_home` → `lib/screens/dashboard_home_screen.dart`
    -   `/leaderboard` → `lib/screens/leaderboard_screen.dart`
    -   `/goals` → `lib/screens/goals_screen.dart`
    -   `/profile` → `lib/screens/profile_screen.dart`

### Data & Services

-   **Data Source**: The app uses Google's **Firestore** as its primary database for all data, including users, products, sales, and rewards.
-   **Service Layer**: Data fetching and business logic are handled in the `lib/services/` directory. Each file corresponds to a specific data model (e.g., `user_service.dart`, `product_service.dart`).

### State Management

-   **Approach**: The app uses the **Provider** package for state management.
-   **Location**: State management logic is centralized in the `lib/controllers/` directory. Each provider (e.g., `AuthProvider`, `GoalProvider`) manages a specific piece of the app's state.

### Integrations

-   **Firebase Authentication**: For user sign-up and sign-in.
    -   *Setup*: `lib/services/auth_service.dart`
-   **Mobile Scanner**: For barcode scanning functionality.
    -   *Setup*: `lib/screens/barcode_scanner_screen.dart`
-   **Image Picker**: For selecting profile images.
    -   *Setup*: `lib/screens/profile_screen.dart`

### Key Packages

-   **`firebase_core`**, **`cloud_firestore`**, **`firebase_auth`**: For Firebase integration.
-   **`provider`**: For state management.
-   **`mobile_scanner`**: For scanning barcodes.
-   **`image_picker`**: For picking images from the gallery or camera.
-   **`google_fonts`**: For custom fonts.

### Gaps/Unclear

-   **Notifications**: The UI shows a notification icon, but the implementation for receiving push notifications is unclear. The `NotificationService` only fetches notifications from Firestore.
-   **Admin Panel**: The user approval flow implies an admin interface exists, but it is not present in this project.
