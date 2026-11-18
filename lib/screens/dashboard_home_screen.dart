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
import 'package:novopharma/design/design.dart';
import 'package:novopharma/services/popup_service.dart';
import 'package:novopharma/widgets/popup_dialog.dart';
import 'package:novopharma/widgets/birthday_popup_dialog.dart';
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

  String _formatPoints(num value) {
    final double d = value.toDouble();
    if (d % 1 == 0) {
      return d.toInt().toString();
    }
    return d.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

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

  Future<void> _checkAndShowBirthdayPopup(BuildContext context, UserModel user) async {
    if (!user.birthdayNotif) return;
    if (user.dateOfBirth == null) return;

    final now = DateTime.now();
    final dob = user.dateOfBirth!;
    final isBirthdayToday = (dob.month == now.month && dob.day == now.day);
    if (!isBirthdayToday) return;

    // Ensure shown only ONCE per birthday
    final prefs = await SharedPreferences.getInstance();
    final key = 'birthday_popup_shown_${user.uid}_${now.year}_${now.month}_${now.day}';
    final alreadyShown = prefs.getBool(key) ?? false;
    if (alreadyShown) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('paramsBirthdayNotification')
          .doc('config')
          .get();

      if (!doc.exists) return;
      final data = doc.data() ?? {};
      final String title = data['title'] ?? 'Joyeux Anniversaire ! 🎉';
      final String description = data['description'] ??
          'Toute l\'équipe vous souhaite un très joyeux anniversaire et vous offre des points bonus !';
      final num? points = data['points'];

      // Mark as shown today BEFORE showing dialog
      await prefs.setBool(key, true);

      if (context.mounted) {
        await showBirthdayPopupDialog(
          context: context,
          title: title,
          description: description,
          points: points,
        );
      }
    } catch (e) {
      print('⚠️ [DASHBOARD] Error checking birthday popup config: $e');
    }
  }

  Future<void> _checkAndShowPopup(UserModel? user) async {
    if (user == null) return;
    final popups = await PopupService().checkAndGetActivePopups(user);
    if (popups.isNotEmpty && mounted) {
      await showPremiumPopup(context, popups);
    }
    if (mounted) {
      await _checkAndShowBirthdayPopup(context, user);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: BottomNavigationScaffoldWrapper(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        child: Consumer6<
          AuthProvider,
          LeaderboardProvider,
          GoalProvider,
          BadgeProvider,
          RedeemedRewardsProvider,
          NotificationProvider
        >(
          builder: (
            context,
            auth,
            leaderboard,
            goal,
            badge,
            redeemedRewards,
            notification,
            child,
          ) {
            final user = auth.userProfile;
            if (user == null) {
              return const Center(child: CapsuleLoader());
            }
            return _buildHome(context, l10n, user, goal, badge, notification);
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Layout
  // ---------------------------------------------------------------------

  static const double _capsuleHeight = 132;

  Widget _buildHome(
    BuildContext context,
    AppLocalizations l10n,
    UserModel user,
    GoalProvider goal,
    BadgeProvider badge,
    NotificationProvider notification,
  ) {
    final media = MediaQuery.of(context);
    final isWide = media.size.width > 600;
    final maxWidth = isWide ? 640.0 : double.infinity;
    final isDermo = user.role == 'Dermo-conseiller';

    Widget centered(Widget child) => Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        );

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: media.padding.bottom + 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ink hero: who you are, what you have, what you can do with it.
          InkHero(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              10,
              AppSpace.page,
              26,
            ),
            child: centered(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Entrance(
                    offset: const Offset(0, -12),
                    child: DashboardHeader(
                      user: user,
                      unreadNotifications: notification.unreadCount,
                      onNotificationTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Entrance(
                    delay: const Duration(milliseconds: 120),
                    scaleFrom: 0.94,
                    child: _buildPointsCapsule(user, l10n),
                  ),
                  Consumer<PluxeeRedemptionProvider>(
                    builder: (context, pluxee, _) {
                      final pending = pluxee.totalPendingPoints;
                      if (pending <= 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Entrance(
                          delay: const Duration(milliseconds: 200),
                          child: _buildPendingRow(pending),
                        ),
                      );
                    },
                  ),
                  if (!isDermo) ...[
                    const SizedBox(height: 16),
                    Entrance(
                      delay: const Duration(milliseconds: 240),
                      child: PrimaryButton.coral(
                        label: l10n.redeemYourPoints,
                        icon: Icons.card_giftcard_rounded,
                        onPressed: () =>
                            Navigator.pushNamed(context, '/rewards'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              22,
              AppSpace.page,
              0,
            ),
            child: centered(_buildShortcuts(context, l10n, user, goal, badge)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // The points capsule — a glass gélule floating on the aurora. The indigo
  // half holds what you can spend, the clear half what you have earned.
  // ---------------------------------------------------------------------

  Widget _buildPointsCapsule(UserModel user, AppLocalizations l10n) {
    final num usable = user.points;
    final num cumulative = user.totalPointsValidated;
    const radius = BorderRadius.all(Radius.circular(_capsuleHeight / 2));
    final muted = Colors.white.withValues(alpha: 0.78);

    return Sheen(
      borderRadius: radius,
      delay: const Duration(milliseconds: 900),
      period: const Duration(seconds: 7),
      intensity: 0.2,
      child: Glass(
        style: GlassStyle.dark,
        blur: Glass.frost,
        height: _capsuleHeight,
        borderRadius: radius,
        child: Stack(
          children: [
            // The tinted half.
            Positioned.fill(
              child: FractionallySizedBox(
                widthFactor: 0.5,
                alignment: Alignment.centerLeft,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.indigoBright.withValues(alpha: 0.85),
                        AppColors.indigo.withValues(alpha: 0.62),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // The seam where the two halves of the capsule meet.
            Align(
              child: Container(
                width: 1.2,
                color: Colors.white.withValues(alpha: 0.28),
              ),
            ),
            // Gloss along the top, the way a capsule catches light.
            Positioned(
              top: 7,
              left: 52,
              right: 52,
              height: 12,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.16),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _capsuleHalf(
                    label: l10n.currentPointsBalance.replaceAll('\n', ' '),
                    value: usable,
                    foreground: Colors.white,
                    muted: muted,
                    padding: const EdgeInsets.only(left: 30, right: 12),
                  ),
                ),
                Expanded(
                  child: _capsuleHalf(
                    label: 'Total points cumulés',
                    value: cumulative,
                    foreground: Colors.white,
                    muted: muted,
                    padding: const EdgeInsets.only(left: 20, right: 24),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _capsuleHalf({
    required String label,
    required num value,
    required Color foreground,
    required Color muted,
    required EdgeInsets padding,
  }) {
    return Padding(
      padding: padding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.label(size: 12.5, color: muted, letterSpacing: 0),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                CountUp(
                  value: value,
                  style: AppText.display(size: 32, color: foreground),
                ),
                const SizedBox(width: 5),
                Text(
                  'pts',
                  style: AppText.label(size: 14, color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRow(num pendingPoints) {
    return SoftCard(
      style: GlassStyle.dark,
      radius: AppRadii.md,
      shadow: false,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(
            Icons.hourglass_top_rounded,
            color: AppColors.amber,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Points en attente',
              style: AppText.body(
                size: 14.5,
                weight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.82),
              ),
            ),
          ),
          Text(
            '${_formatPoints(pendingPoints)} pts',
            style: AppText.display(size: 18, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Shortcuts — the day's main action first and wide, the rest in pairs.
  // ---------------------------------------------------------------------

  Widget _buildShortcuts(
    BuildContext context,
    AppLocalizations l10n,
    UserModel user,
    GoalProvider goal,
    BadgeProvider badge,
  ) {
    final isDermo = user.role == 'Dermo-conseiller';
    final awarded = badge.badges.where((b) => b.isAwarded).length;

    final featured = isDermo
        ? _Shortcut(
            title: 'Check-in / Check-out',
            icon: Icons.pin_drop_rounded,
            tone: Tone.peach,
            onTap: () => _handleCheckIn(context),
          )
        : _Shortcut(
            title: l10n.manualSale,
            icon: Icons.shopping_cart_rounded,
            tone: Tone.peach,
            onTap: () => Navigator.pushNamed(context, '/manual-sale'),
          );

    final rest = <_Shortcut>[
      _Shortcut(
        title: l10n.performanceTracking,
        icon: Icons.leaderboard_rounded,
        tone: Tone.mint,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
        ),
      ),
      _Shortcut(
        title: l10n.objectives,
        icon: Icons.flag_rounded,
        tone: Tone.coral,
        chip: goal.goals.isEmpty ? null : '${goal.goals.length}',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GoalsScreen()),
        ),
      ),
      if (!isDermo)
        _Shortcut(
          title: l10n.lastBadge,
          icon: Icons.military_tech_rounded,
          tone: Tone.amber,
          chip: badge.badges.isEmpty ? null : '$awarded/${badge.badges.length}',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BadgesScreen()),
          ),
        ),
      _Shortcut(
        title: 'Challenges',
        icon: Icons.emoji_events_rounded,
        tone: Tone.indigo,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChallengesListScreen()),
        ),
      ),
    ];

    const gap = 14.0;
    const base = Duration(milliseconds: 320);
    final rows = <Widget>[
      Entrance(delay: base, child: _WideShortcutTile(shortcut: featured)),
    ];
    var order = 1;
    for (var i = 0; i < rest.length; i += 2) {
      final pair = rest.skip(i).take(2).toList();
      rows.add(const SizedBox(height: gap));
      if (pair.length == 1) {
        rows.add(
          Entrance.staggered(
            index: order++,
            base: base,
            child: _WideShortcutTile(shortcut: pair.first),
          ),
        );
      } else {
        rows.add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Entrance.staggered(
                    index: order++,
                    base: base,
                    child: _ShortcutTile(shortcut: pair[0]),
                  ),
                ),
                const SizedBox(width: gap),
                Expanded(
                  child: Entrance.staggered(
                    index: order++,
                    base: base,
                    child: _ShortcutTile(shortcut: pair[1]),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  // ---------------------------------------------------------------------
  // Check-in (dermo-conseiller) — unchanged behaviour.
  // ---------------------------------------------------------------------

  Future<void> _handleCheckIn(BuildContext context) async {
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
      return;
    }

    if (!context.mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.userProfile;
    if (user != null) {
      try {
        final activeVisitsQuery = await FirebaseFirestore.instance
            .collection('visits_history')
            .where('dermoId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'active')
            .get();

        final activeDocs = activeVisitsQuery.docs;

        if (activeDocs.length == 1) {
          final visitData = activeDocs.first.data();
          final visitId = visitData['visitId'] ?? activeDocs.first.id;
          final pharmacyId = visitData['pharmacyId'] ?? '';
          final pharmacyName = visitData['pharmacyName'] ?? '';
          final pointOfSale = visitData['pointOfSale'];

          await prefs.setString('active_visit_id', visitId.toString());
          await prefs.setString('active_pharmacy_id', pharmacyId.toString());
          await prefs.setString(
            'active_pharmacy_name',
            pharmacyName.toString(),
          );
          if (pointOfSale != null && pointOfSale.toString().isNotEmpty) {
            await prefs.setString(
              'active_point_of_sale',
              pointOfSale.toString(),
            );
          } else {
            await prefs.remove('active_point_of_sale');
          }

          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PharmacyProfileScreen(
                  pharmacyId: pharmacyId.toString(),
                  pharmacyName: pharmacyName.toString(),
                ),
              ),
            );
          }
          return;
        } else if (activeDocs.length > 1) {
          if (context.mounted) {
            showGlassDialog<void>(
              context: context,
              child: Builder(
                builder: (context) => ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: BlisterIcon(
                          icon: Icons.error_outline_rounded,
                          tone: Tone.coral,
                          size: 64,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Visites actives multiples",
                        textAlign: TextAlign.center,
                        style: AppText.display(size: 21),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Vous avez plusieurs visites actives enregistrées. Veuillez fermer vos anciennes visites ou contacter votre responsable pour les fermer.",
                        textAlign: TextAlign.center,
                        style: AppText.body(
                          size: 14.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 22),
                      PrimaryButton(
                        label: "OK",
                        height: 50,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return;
        }
      } catch (e) {
        debugPrint("Error checking active visits: $e");
      }
    }

    if (context.mounted) {
      Navigator.pushNamed(context, '/pharmacy_selection');
    }
  }
}

class _Shortcut {
  final String title;
  final IconData icon;
  final Tone tone;
  final String? chip;
  final VoidCallback onTap;

  const _Shortcut({
    required this.title,
    required this.icon,
    required this.tone,
    required this.onTap,
    this.chip,
  });
}

/// The full-width tile for the action people open the app to do.
class _WideShortcutTile extends StatelessWidget {
  final _Shortcut shortcut;
  const _WideShortcutTile({required this.shortcut});

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: shortcut.onTap,
      semanticLabel: shortcut.title,
      padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
      child: Row(
        children: [
          BlisterIcon(icon: shortcut.icon, tone: shortcut.tone, size: 56),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              shortcut.title.replaceAll('\n', ' '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.display(size: 19),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: shortcut.tone.tint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 20,
              color: shortcut.tone.deep,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  final _Shortcut shortcut;
  const _ShortcutTile({required this.shortcut});

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: shortcut.onTap,
      semanticLabel: shortcut.title.replaceAll('\n', ' '),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BlisterIcon(icon: shortcut.icon, tone: shortcut.tone),
              const Spacer(),
              if (shortcut.chip != null)
                TonePill(label: shortcut.chip!, tone: shortcut.tone),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            shortcut.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.display(size: 17, height: 1.15),
          ),
        ],
      ),
    );
  }
}
