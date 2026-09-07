import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';

import 'package:novopharma/controllers/badge_provider.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/controllers/goal_provider.dart';
import 'package:novopharma/controllers/quiz_provider.dart';
import 'package:novopharma/controllers/rewards_controller.dart';
import 'package:novopharma/controllers/redeemed_rewards_provider.dart';
import 'package:novopharma/controllers/pluxee_redemption_provider.dart';
import 'package:novopharma/controllers/leaderboard_provider.dart';
import 'package:novopharma/controllers/sales_history_provider.dart';
import 'package:novopharma/controllers/scan_provider.dart';
import 'package:novopharma/controllers/locale_provider.dart';
import 'package:novopharma/controllers/formation_provider.dart';
import 'package:novopharma/controllers/actualite_provider.dart';
import 'package:novopharma/controllers/notification_provider.dart';
import 'package:novopharma/services/notification_service.dart';
import 'package:novopharma/services/chottu_link_service.dart';
import 'package:novopharma/firebase_options.dart';
import 'package:novopharma/navigation.dart';
import 'package:novopharma/navigation_observer.dart';
import 'package:novopharma/theme.dart';
import 'package:novopharma/screens/dashboard_home_screen.dart';
import 'package:novopharma/screens/leaderboard_screen.dart';
import 'package:novopharma/screens/profile_screen.dart';
import 'package:novopharma/screens/pharmacy_selection_screen.dart';
import 'package:novopharma/screens/pharmacy_profile_screen.dart';
import 'package:novopharma/screens/goals_screen.dart';
import 'package:novopharma/screens/barcode_scanner_screen.dart';
import 'package:novopharma/screens/login_screen.dart';
import 'package:novopharma/screens/pluxee_redemption_screen.dart';
import 'package:novopharma/screens/formations_screen.dart';
import 'package:novopharma/screens/actualites_screen.dart';
import 'package:novopharma/screens/badges_screen.dart';
import 'package:novopharma/screens/formation_details_screen.dart';
import 'package:novopharma/screens/splash_screen.dart';
import 'package:novopharma/screens/manual_sale_screen.dart';
import 'package:novopharma/screens/product_screen.dart';
import 'package:novopharma/screens/sales_history_screen.dart';
import 'package:novopharma/screens/stock_brand_selection_screen.dart';
import 'package:novopharma/screens/brand_stock_input_screen.dart';
import 'package:novopharma/screens/stock_review_screen.dart';
import 'package:novopharma/models/blog_post.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chottu_link/chottu_link.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


/// Allows TLS connections to novopharma.tn on devices where modern Sectigo Root R46 is not in the OS trust store.
class AppHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        if (host == 'novopharma.tn' || host.endsWith('.novopharma.tn')) {
          return true;
        }
        return false;
      };
  }
}
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    HttpOverrides.global = AppHttpOverrides();
  }
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  /// âœ… Initialize the ChottuLink SDK
  await ChottuLink.init(apiKey: dotenv.env['CHOTTULINK_API_KEY'] ?? '');

  // Initialize ChottuLink handling
  ChottuLinkService().initialize();

  // Initialize notification service
  await NotificationService().initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LeaderboardProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProxyProvider<AuthProvider, GoalProvider>(
          create: (context) =>
              GoalProvider(Provider.of<AuthProvider>(context, listen: false)),
          update: (context, auth, previous) => previous!..update(auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, BadgeProvider>(
          create: (context) =>
              BadgeProvider(Provider.of<AuthProvider>(context, listen: false)),
          update: (context, auth, previous) => previous!..update(auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, RedeemedRewardsProvider>(
          create: (context) => RedeemedRewardsProvider(
            Provider.of<AuthProvider>(context, listen: false),
          ),
          update: (context, auth, previous) => previous!..update(auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, PluxeeRedemptionProvider>(
          create: (context) => PluxeeRedemptionProvider(
            Provider.of<AuthProvider>(context, listen: false),
          ),
          update: (context, auth, previous) => previous!..update(auth),
        ),
        ChangeNotifierProvider(create: (_) => QuizProvider()),
        ChangeNotifierProvider(create: (_) => ScanProvider()),
        ChangeNotifierProvider(create: (_) => SalesHistoryProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => RewardsController()),
        ChangeNotifierProvider(create: (_) => FormationProvider()),
        ChangeNotifierProvider(create: (_) => ActualiteProvider()),
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
      title: 'MyChallenge',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: localeProvider.locale,
      home: const SplashScreen(),
      navigatorObservers: [routeObserver],
      onGenerateRoute: (settings) {
        // Handle dynamic routes for formations from notifications
        if (settings.name?.startsWith('/formation/') == true) {
          final formationId = settings.name!.split('/').last;
          return MaterialPageRoute(
            builder: (context) => FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('blogPosts')
                  .doc(formationId)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    !snapshot.data!.exists) {
                  return Scaffold(
                    appBar: AppBar(title: const Text('Erreur')),
                    body: const Center(child: Text('Formation introuvable')),
                  );
                }
                final formation = BlogPost.fromFirestore(snapshot.data!);
                return FormationDetailsScreen(formation: formation);
              },
            ),
          );
        }
        return null;
      },
      routes: {
        '/dashboard_home': (context) => const DashboardHomeScreen(),
        '/leaderboard': (context) => const LeaderboardScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/goals': (context) => const GoalsScreen(),
        '/scanner': (context) => const BarcodeScannerScreen(),
        '/login': (context) => const LoginScreen(),
        '/rewards': (context) => const PluxeeRedemptionScreen(),
        '/manual-sale': (context) => const ManualSaleScreen(),
        '/formations': (context) => const FormationsScreen(),
        '/history': (context) => const SalesHistoryScreen(),
        '/sales-history': (context) => const SalesHistoryScreen(),
        '/badges': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          return BadgesScreen(initialBadgeId: args?['id']);
        },
        '/actualites': (context) => const ActualitesScreen(),
        '/pharmacy_selection': (context) => const PharmacySelectionScreen(),
        '/pharmacy_profile': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          return PharmacyProfileScreen(
            pharmacyId: args?['pharmacyId'] ?? '',
            pharmacyName: args?['pharmacyName'] ?? '',
          );
        },
        '/stock_brand_selection': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          return StockBrandSelectionScreen(
            pharmacyId: args?['pharmacyId'] ?? '',
            pharmacyName: args?['pharmacyName'] ?? '',
          );
        },
        '/brand_stock_input': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          return BrandStockInputScreen(
            pharmacyId: args?['pharmacyId'] ?? '',
            pharmacyName: args?['pharmacyName'] ?? '',
            brand: args?['brand'] ?? '',
          );
        },
        '/stock_review': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          return StockReviewScreen(
            pharmacyId: args?['pharmacyId'] ?? '',
            pharmacyName: args?['pharmacyName'] ?? '',
          );
        },
        '/product': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          final sku = args?['sku'] as String?;
          final id = args?['id'] as String?;
          return ProductScreen(sku: sku, id: id);
        },
      },
    );
  }
}

