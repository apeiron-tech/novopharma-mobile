import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/controllers/badge_provider.dart';
import 'package:novopharma/controllers/goal_provider.dart';
import 'package:novopharma/controllers/leaderboard_provider.dart';
import 'package:novopharma/controllers/notification_provider.dart';
import 'package:novopharma/controllers/pluxee_redemption_provider.dart';
import 'package:novopharma/controllers/redeemed_rewards_provider.dart';
import 'package:novopharma/models/user_model.dart';
import 'package:novopharma/screens/badges_screen.dart';
import 'package:novopharma/screens/goals_screen.dart';
import 'package:novopharma/screens/leaderboard_screen.dart';
import 'package:novopharma/screens/notifications_screen.dart';
import 'package:novopharma/widgets/dashboard_header.dart';
import 'package:novopharma/widgets/bottom_navigation_bar.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';
import 'package:novopharma/theme.dart';
import 'package:novopharma/services/popup_service.dart';
import 'package:novopharma/widgets/popup_dialog.dart';
import 'package:novopharma/screens/challenges_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novopharma/screens/pharmacy_profile_screen.dart';

class DashboardHomeScreen extends StatefulWidget {
  const DashboardHomeScreen({super.key});

  @override
  State<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends State<DashboardHomeScreen> {
  int _selectedIndex = 0;
  int _currentYearPoints = 0;
  bool _isCalculatingYearPoints = true;
  bool _hasCalculatedYearPoints = false; // Cache flag
  DateTime? _lastCalculationTime; // Track when we last calculated
  static const Duration _cacheValidity = Duration(minutes: 2);

  @override
  void initState() {
    super.initState();
    print('🟢 [DASHBOARD] ===== DASHBOARD INIT START =====');
    final initStartTime = DateTime.now();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🟢 [DASHBOARD] Post-frame callback executing...');
      final callbackStartTime = DateTime.now();

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final notificationProvider = Provider.of<NotificationProvider>(
        context,
        listen: false,
      );

      print('🟢 [DASHBOARD] Fetching leaderboard (yearly)...');
      final leaderboardStart = DateTime.now();
      Provider.of<LeaderboardProvider>(
        context,
        listen: false,
      ).fetchLeaderboard('yearly');
      final leaderboardDuration = DateTime.now().difference(leaderboardStart);
      print(
        '✅ [DASHBOARD] Leaderboard fetch initiated in ${leaderboardDuration.inMilliseconds}ms',
      );

      // Only calculate if not already done OR cache expired
      final now = DateTime.now();
      final cacheExpired =
          _lastCalculationTime == null ||
          now.difference(_lastCalculationTime!) > _cacheValidity;

      if (!_hasCalculatedYearPoints || cacheExpired) {
        if (cacheExpired && _hasCalculatedYearPoints) {
          print('⏰ [DASHBOARD] Year points cache expired, recalculating...');
        } else {
          print('🟢 [DASHBOARD] Starting year points calculation...');
        }
        _calculateCurrentYearPoints();
      } else {
        print('💾 [DASHBOARD] Using cached year points: $_currentYearPoints');
      }

      // Initialize notifications asynchronously without blocking
      final userId = authProvider.userProfile?.uid;
      if (userId != null) {
        print('🟢 [DASHBOARD] Initializing notifications for user: $userId');
        // Run in background without awaiting
        Future.microtask(
          () => notificationProvider.initializeNotifications(userId),
        );

        // Check for active popups
        _checkAndShowPopup(authProvider.userProfile);
      } else {
        print('⚠️ [DASHBOARD] No userId found for notifications');
      }

      final callbackDuration = DateTime.now().difference(callbackStartTime);
      final totalInitDuration = DateTime.now().difference(initStartTime);
      print(
        '✅ [DASHBOARD] Post-frame callback completed in ${callbackDuration.inMilliseconds}ms',
      );
      print(
        '✅ [DASHBOARD] Total init time: ${totalInitDuration.inMilliseconds}ms',
      );
      print('🟢 [DASHBOARD] ===== DASHBOARD INIT COMPLETE =====');
    });
  }

  Future<void> _calculateCurrentYearPoints() async {
    print('🔵 [DASHBOARD] ===== Starting Year Points Calculation =====');
    final startTime = DateTime.now();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userProfile?.uid;

    if (userId == null) {
      print('⚠️ [DASHBOARD] No userId found, aborting calculation');
      if (mounted) {
        setState(() {
          _isCalculatingYearPoints = false;
          _currentYearPoints = 0;
          _hasCalculatedYearPoints = true;
        });
      }
      return;
    }

    try {
      final now = DateTime.now();
      final yearStart = DateTime(now.year, 1, 1);
      print('📅 [DASHBOARD] Calculating points for year: ${now.year}');

      final queryStartTime = DateTime.now();
      print('🔄 [DASHBOARD] Starting parallel Firestore queries...');

      // Execute all queries in PARALLEL for better performance
      final results = await Future.wait([
        // Query 1: Sales points
        FirebaseFirestore.instance
            .collection('sales')
            .where('userId', isEqualTo: userId)
            .where(
              'saleDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(yearStart),
            )
            .get(),
        // Query 2: Quiz points
        FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('quizAttempts')
            .where(
              'timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(yearStart),
            )
            .get(),
        // Query 3: Goal points
        FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('userGoalProgress')
            .where(
              'completedAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(yearStart),
            )
            .get(),
        // Query 4: Badge points
        FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('userBadges')
            .where(
              'awardedAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(yearStart),
            )
            .get(),
      ]);

      final queryDuration = DateTime.now().difference(queryStartTime);
      print(
        '✅ [DASHBOARD] Parallel queries completed in ${queryDuration.inMilliseconds}ms',
      );

      // Process results
      int salesPoints = 0;
      for (var doc in results[0].docs) {
        final pointsValue = doc.data()['pointsEarned'];
        salesPoints += (pointsValue is num ? pointsValue.toInt() : 0);
      }
      print(
        '💰 [DASHBOARD] Sales: ${results[0].docs.length} docs, $salesPoints points',
      );

      int quizPoints = 0;
      for (var doc in results[1].docs) {
        final pointsValue = doc.data()['pointsEarned'];
        quizPoints += (pointsValue is num ? pointsValue.toInt() : 0);
      }
      print(
        '📝 [DASHBOARD] Quizzes: ${results[1].docs.length} docs, $quizPoints points',
      );

      int goalPoints = 0;
      for (var doc in results[2].docs) {
        final pointsValue = doc.data()['pointsAwarded'];
        goalPoints += (pointsValue is num ? pointsValue.toInt() : 0);
      }
      print(
        '🎯 [DASHBOARD] Goals: ${results[2].docs.length} docs, $goalPoints points',
      );

      // Process badge points EFFICIENTLY - batch fetch badge details
      int badgePoints = 0;
      final badgeDocs = results[3].docs;
      print('🏅 [DASHBOARD] Found ${badgeDocs.length} user badges');

      if (badgeDocs.isNotEmpty) {
        final badgeStartTime = DateTime.now();
        // Collect unique badge IDs
        final badgeIds = badgeDocs
            .map((doc) => doc.data()['badgeId'] as String?)
            .where((id) => id != null)
            .cast<String>()
            .toSet()
            .toList();

        print(
          '🔍 [DASHBOARD] Fetching details for ${badgeIds.length} unique badges...',
        );

        if (badgeIds.isNotEmpty) {
          // Batch fetch all badge details in ONE query (or batches of 10 due to Firestore limit)
          for (int i = 0; i < badgeIds.length; i += 10) {
            final batch = badgeIds.skip(i).take(10).toList();
            try {
              final badgeDetailsQuery = await FirebaseFirestore.instance
                  .collection('badges')
                  .where(FieldPath.documentId, whereIn: batch)
                  .get();

              final badgePointsMap = <String, int>{};
              for (var badgeDoc in badgeDetailsQuery.docs) {
                final pointsValue = badgeDoc.data()['points'];
                if (pointsValue != null && pointsValue is num) {
                  badgePointsMap[badgeDoc.id] = pointsValue.toInt();
                }
              }

              // Sum up points for all user badges
              for (var userBadgeDoc in badgeDocs) {
                final badgeId = userBadgeDoc.data()['badgeId'] as String?;
                if (badgeId != null && badgePointsMap.containsKey(badgeId)) {
                  badgePoints += badgePointsMap[badgeId]!;
                }
              }
            } catch (e) {
              print('⚠️ [DASHBOARD] Error fetching badge batch: $e');
            }
          }

          final badgeDuration = DateTime.now().difference(badgeStartTime);
          print(
            '✅ [DASHBOARD] Badge details fetched in ${badgeDuration.inMilliseconds}ms, $badgePoints points',
          );
        }
      }

      final totalDuration = DateTime.now().difference(startTime);
      final totalPoints = salesPoints + quizPoints + goalPoints + badgePoints;

      print('🎉 [DASHBOARD] ===== Calculation Complete =====');
      print(
        '📊 [DASHBOARD] Total Points: $totalPoints (Sales: $salesPoints, Quiz: $quizPoints, Goals: $goalPoints, Badges: $badgePoints)',
      );
      print('⏱️ [DASHBOARD] Total time: ${totalDuration.inMilliseconds}ms');
      print('🔵 [DASHBOARD] =====================================');

      if (mounted) {
        setState(() {
          _currentYearPoints = totalPoints;
          _isCalculatingYearPoints = false;
          _hasCalculatedYearPoints = true;
          _lastCalculationTime = DateTime.now(); // Update cache timestamp
        });
      }
    } catch (e) {
      final errorDuration = DateTime.now().difference(startTime);
      print('❌ [DASHBOARD] Error after ${errorDuration.inMilliseconds}ms: $e');
      if (mounted) {
        setState(() {
          _isCalculatingYearPoints = false;
          _currentYearPoints = 0;
          _hasCalculatedYearPoints = true;
        });
      }
    }
  }

  Future<void> _checkAndShowPopup(UserModel? user) async {
    final popups = await PopupService().checkAndGetActivePopups(user);
    if (popups.isNotEmpty && mounted) {
      showPremiumPopup(context, popups);
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🎨 [DASHBOARD] Build method called');
    final buildStartTime = DateTime.now();

    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Stack(
        children: [
          BottomNavigationScaffoldWrapper(
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            child:
                Consumer6<
                  AuthProvider,
                  LeaderboardProvider,
                  GoalProvider,
                  BadgeProvider,
                  RedeemedRewardsProvider,
                  NotificationProvider
                >(
                  builder:
                      (
                        context,
                        auth,
                        leaderboard,
                        goal,
                        badge,
                        redeemedRewards,
                        notification,
                        child,
                      ) {
                        print('🔍 [DASHBOARD] Consumer6 builder executing...');
                        print(
                          '   └─ AuthProvider: ${auth.userProfile != null ? "✓" : "✗"}',
                        );
                        print(
                          '   └─ LeaderboardProvider: ${leaderboard.isLoading ? "⏳ Loading" : "✓ Ready"}',
                        );
                        print(
                          '   └─ GoalProvider: ${goal.isLoading ? "⏳ Loading" : "✓ Ready"}',
                        );
                        print(
                          '   └─ BadgeProvider: ${badge.isLoading ? "⏳ Loading" : "✓ Ready"}',
                        );
                        print(
                          '   └─ RedeemedRewardsProvider: ${redeemedRewards.isLoading ? "⏳ Loading" : "✓ Ready"}',
                        );

                        final user = auth.userProfile;
                        if (user == null ||
                            leaderboard.isLoading ||
                            goal.isLoading ||
                            badge.isLoading ||
                            redeemedRewards.isLoading) {
                          print(
                            '⏳ [DASHBOARD] Showing loading indicator - waiting for providers',
                          );
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final buildDuration = DateTime.now().difference(
                          buildStartTime,
                        );
                        print(
                          '✅ [DASHBOARD] All providers ready! Building UI (took ${buildDuration.inMilliseconds}ms)',
                        );

                        return Container(
                          color: Colors.white,
                          child: SafeArea(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              child: Column(
                                children: [
                                  DashboardHeader(
                                    user: user,
                                    unreadNotifications:
                                        notification.unreadCount,
                                    onNotificationTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const NotificationsScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  Consumer<PluxeeRedemptionProvider>(
                                    builder: (context, pluxee, _) =>
                                        _buildPointsCard(
                                          user,
                                          l10n,
                                          redeemedRewards,
                                          pluxee,
                                        ),
                                  ),
                                  const SizedBox(height: 28),
                                  _buildDashboardGrid(
                                    context,
                                    l10n,
                                    user,
                                    leaderboard,
                                    goal,
                                    badge,
                                    redeemedRewards,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsCard(
    UserModel? user,
    AppLocalizations l10n,
    RedeemedRewardsProvider redeemedRewards,
    PluxeeRedemptionProvider pluxeeRedemption,
  ) {
    final totalPoints = user?.points ?? 0;
    final pendingPoints = pluxeeRedemption.totalPendingPoints;
    final allTimePoints = pluxeeRedemption.allTimePoints;

    final double screenWidth = MediaQuery.of(context).size.width;
    final double scaleFactor = (screenWidth > 600) ? 1.4 : 1.0;

    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                LightModeColors.lightPrimary,
                LightModeColors.lightSecondary,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: LightModeColors.lightPrimary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative circles in background
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 100 * scaleFactor,
                  height: 100 * scaleFactor,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: -30,
                child: Container(
                  width: 120 * scaleFactor,
                  height: 120 * scaleFactor,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              // Main content
              Padding(
                padding: EdgeInsets.all(24 * scaleFactor),
                child: Row(
                  children: [
                    // Current year points section (left side)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'TOTAL POINTS CUMULÉS ',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11 * scaleFactor,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          SizedBox(height: 16 * scaleFactor),
                          _isCalculatingYearPoints
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      allTimePoints.toString().replaceAllMapped(
                                        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                        (Match m) => '${m[1]} ',
                                      ),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 32 * scaleFactor,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -1,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(
                                        'pts',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 16 * scaleFactor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ],
                      ),
                    ),
                    // Vertical divider
                    Container(
                      width: 1,
                      height: 80 * scaleFactor,
                      margin: EdgeInsets.symmetric(horizontal: 16 * scaleFactor),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(0),
                            Colors.white.withOpacity(0.3),
                            Colors.white.withOpacity(0),
                          ],
                        ),
                      ),
                    ),
                    // Current balance section (right side)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              l10n.currentPointsBalance.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11 * scaleFactor,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          SizedBox(height: 16 * scaleFactor),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                totalPoints.toString().replaceAllMapped(
                                  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                  (Match m) => '${m[1]} ',
                                ),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32 * scaleFactor,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  'pts',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 16 * scaleFactor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (pendingPoints > 0) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: LightModeColors.lightOutlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.hourglass_empty_rounded,
                    color: Color(0xFFD97706),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Points en attente',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$pendingPoints points',
                        style: const TextStyle(
                          color: LightModeColors.dashboardTextPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        _buildRedeemButton(context, l10n),
      ],
    );
  }

  Widget _buildRedeemButton(BuildContext context, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: LightModeColors.lightError,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(context, '/rewards');
          },
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.card_giftcard_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                l10n.redeemYourPoints,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardGrid(
    BuildContext context,
    AppLocalizations l10n,
    UserModel user,
    LeaderboardProvider leaderboard,
    GoalProvider goal,
    BadgeProvider badge,
    RedeemedRewardsProvider redeemedRewards,
  ) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.0,
      children: [
        if (user.role == 'Dermo-conseiller') _buildCheckInCard(context),
        if (user.role != 'Dermo-conseiller')
          _buildManualSaleCard(context, l10n),
        _buildLeaderboardCard(context, l10n),
        _buildGoalsCard(context, l10n),
        _buildBadgesCard(context, l10n),
        _buildChallengesCard(context, l10n),
      ],
    );
  }

  Widget _buildManualSaleCard(BuildContext context, AppLocalizations l10n) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double scaleFactor = (screenWidth > 600) ? 1.4 : 1.0;
    final double iconSize = 40 * scaleFactor;
    final double paddingVal = 16 * scaleFactor;
    final double fontSizeVal = 14 * scaleFactor;
    final double spacingVal = 12 * scaleFactor;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LightModeColors.lightOutlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(context, '/manual-sale');
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(paddingVal),
                  decoration: const BoxDecoration(
                    color: LightModeColors.warning,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shopping_cart,
                    color: Colors.white,
                    size: iconSize,
                  ),
                ),
                SizedBox(height: spacingVal),
                Text(
                  l10n.manualSale,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSizeVal,
                    fontWeight: FontWeight.bold,
                    color: LightModeColors.dashboardTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardCard(BuildContext context, AppLocalizations l10n) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double scaleFactor = (screenWidth > 600) ? 1.4 : 1.0;
    final double iconSize = 40 * scaleFactor;
    final double paddingVal = 16 * scaleFactor;
    final double fontSizeVal = 14 * scaleFactor;
    final double spacingVal = 12 * scaleFactor;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LightModeColors.lightOutlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
          ),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(paddingVal),
                  decoration: const BoxDecoration(
                    color: LightModeColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: iconSize,
                  ),
                ),
                SizedBox(height: spacingVal),
                Text(
                  l10n.performanceTracking,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSizeVal,
                    fontWeight: FontWeight.bold,
                    color: LightModeColors.dashboardTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoalsCard(BuildContext context, AppLocalizations l10n) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double scaleFactor = (screenWidth > 600) ? 1.4 : 1.0;
    final double iconSize = 40 * scaleFactor;
    final double paddingVal = 16 * scaleFactor;
    final double fontSizeVal = 14 * scaleFactor;
    final double spacingVal = 12 * scaleFactor;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LightModeColors.lightOutlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GoalsScreen()),
          ),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(paddingVal),
                  decoration: BoxDecoration(
                    color: LightModeColors.lightError,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.flag_circle,
                    color: Colors.white,
                    size: iconSize,
                  ),
                ),
                SizedBox(height: spacingVal),
                Text(
                  l10n.objectives,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSizeVal,
                    fontWeight: FontWeight.bold,
                    color: LightModeColors.dashboardTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadgesCard(BuildContext context, AppLocalizations l10n) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double scaleFactor = (screenWidth > 600) ? 1.4 : 1.0;
    final double iconSize = 40 * scaleFactor;
    final double paddingVal = 16 * scaleFactor;
    final double fontSizeVal = 14 * scaleFactor;
    final double spacingVal = 12 * scaleFactor;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LightModeColors.lightOutlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BadgesScreen()),
          ),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(paddingVal),
                  decoration: const BoxDecoration(
                    color: LightModeColors.lightwarning,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.military_tech,
                    color: Colors.white,
                    size: iconSize,
                  ),
                ),
                SizedBox(height: spacingVal),
                Text(
                  l10n.lastBadge,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSizeVal,
                    fontWeight: FontWeight.bold,
                    color: LightModeColors.dashboardTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChallengesCard(BuildContext context, AppLocalizations l10n) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double scaleFactor = (screenWidth > 600) ? 1.4 : 1.0;
    final double iconSize = 40 * scaleFactor;
    final double paddingVal = 16 * scaleFactor;
    final double fontSizeVal = 14 * scaleFactor;
    final double spacingVal = 12 * scaleFactor;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LightModeColors.lightOutlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChallengesListScreen()),
          ),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(paddingVal),
                  decoration: const BoxDecoration(
                    color: LightModeColors.lightPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.white,
                    size: iconSize,
                  ),
                ),
                SizedBox(height: spacingVal),
                Text(
                  "Challenges",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSizeVal,
                    fontWeight: FontWeight.bold,
                    color: LightModeColors.dashboardTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckInCard(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double scaleFactor = (screenWidth > 600) ? 1.4 : 1.0;
    final double iconSize = 40 * scaleFactor;
    final double paddingVal = 16 * scaleFactor;
    final double fontSizeVal = 14 * scaleFactor;
    final double spacingVal = 12 * scaleFactor;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LightModeColors.lightOutlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () async {
            final prefs = await SharedPreferences.getInstance();
            final activeVisitId = prefs.getString('active_visit_id');
            final activePharId = prefs.getString('active_pharmacy_id');
            final activePharName = prefs.getString('active_pharmacy_name');

            if (activeVisitId != null &&
                activePharId != null &&
                activePharName != null) {
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PharmacyProfileScreen(
                      pharmacyId: activePharId,
                      pharmacyName: activePharName,
                    ),
                  ),
                );
              }
            } else {
              if (context.mounted) {
                Navigator.pushNamed(context, '/pharmacy_selection');
              }
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(paddingVal),
                  decoration: const BoxDecoration(
                    color: LightModeColors.warning,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.pin_drop_rounded,
                    color: Colors.white,
                    size: iconSize,
                  ),
                ),
                SizedBox(height: spacingVal),
                Text(
                  "Check-in / Check-out",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSizeVal,
                    fontWeight: FontWeight.bold,
                    color: LightModeColors.dashboardTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
