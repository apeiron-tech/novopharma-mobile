import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';

import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/controllers/goal_provider.dart';
import 'package:novopharma/controllers/fab_visibility_provider.dart';
import 'package:novopharma/controllers/quiz_provider.dart';
import 'package:novopharma/controllers/rewards_controller.dart';
import 'package:novopharma/controllers/leaderboard_provider.dart';
import 'package:novopharma/controllers/sales_history_provider.dart';
import 'package:novopharma/controllers/scan_provider.dart';
import 'package:novopharma/controllers/locale_provider.dart';
import 'package:novopharma/firebase_options.dart';
import 'package:novopharma/navigation.dart';
import 'package:novopharma/screens/auth_wrapper.dart';
import 'package:novopharma/screens/welcome_screen.dart';
import 'package:novopharma/theme.dart';
import 'package:novopharma/screens/dashboard_home_screen.dart';
import 'package:novopharma/screens/leaderboard_screen.dart';
import 'package:novopharma/screens/profile_screen.dart';
import 'package:novopharma/screens/goals_screen.dart';
import 'package:novopharma/screens/barcode_scanner_screen.dart';
import 'package:novopharma/screens/login_screen.dart';
import 'package:novopharma/screens/rewards_screen.dart';
import 'package:novopharma/widgets/rewards_fab_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => GoalProvider()),
        ChangeNotifierProvider(create: (_) => QuizProvider()),
        ChangeNotifierProvider(create: (_) => LeaderboardProvider()),
        ChangeNotifierProvider(create: (_) => ScanProvider()),
        ChangeNotifierProvider(create: (_) => SalesHistoryProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => FabVisibilityProvider()),
      ],
      child: const NovoPharmaApp(),
    ),
  );
}


class NovoPharmaApp extends StatelessWidget {
  const NovoPharmaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'NovoPharma Rewards',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: localeProvider.locale,
      home: const AuthWrapper(),
      routes: {
        '/dashboard_home': (context) => const DashboardHomeScreen(),
        '/leaderboard': (context) => const LeaderboardScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/goals': (context) => const GoalsScreen(),
        '/scanner': (context) => const BarcodeScannerScreen(),
        '/login': (context) => const LoginScreen(),
        '/rewards': (context) => const RewardsScreen(),
      },
      builder: (context, child) {
        return Stack(
          children: [
            child!,
            Consumer<FabVisibilityProvider>(
              builder: (context, fabProvider, _) {
                return Positioned(
                  bottom: 80, // Above bottom navigation
                  right: 20,
                  child: fabProvider.isVisible
                      ? const RewardsFABCore()
                      : const SizedBox.shrink(),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
