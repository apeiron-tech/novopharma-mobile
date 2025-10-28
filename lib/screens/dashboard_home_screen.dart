import 'package:flutter/material.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/controllers/badge_provider.dart';
import 'package:novopharma/controllers/goal_provider.dart';
import 'package:novopharma/controllers/leaderboard_provider.dart';
import 'package:novopharma/controllers/redeemed_rewards_provider.dart';
import 'package:novopharma/models/goal.dart';
import 'package:novopharma/models/user_model.dart';
import 'package:novopharma/screens/badges_screen.dart';
import 'package:novopharma/screens/goals_screen.dart';
import 'package:novopharma/screens/leaderboard_screen.dart';
import 'package:novopharma/screens/product_screen.dart';
import 'package:novopharma/widgets/dashboard_header.dart';
import 'package:novopharma/widgets/bottom_navigation_bar.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';

class DashboardHomeScreen extends StatefulWidget {
  const DashboardHomeScreen({super.key});

  @override
  State<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends State<DashboardHomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LeaderboardProvider>(
        context,
        listen: false,
      ).fetchLeaderboard('yearly');
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Stack(
        children: [
          BottomNavigationScaffoldWrapper(
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            child:
                Consumer5<
                  AuthProvider,
                  LeaderboardProvider,
                  GoalProvider,
                  BadgeProvider,
                  RedeemedRewardsProvider
                >(
                  builder:
                      (
                        context,
                        auth,
                        leaderboard,
                        goal,
                        badge,
                        redeemedRewards,
                        child,
                      ) {
                        final user = auth.userProfile;
                        if (user == null ||
                            leaderboard.isLoading ||
                            goal.isLoading ||
                            badge.isLoading ||
                            redeemedRewards.isLoading) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

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
                                    onNotificationTap: () {},
                                  ),
                                  const SizedBox(height: 20),
                                  _buildSalesCard(user, l10n),
                                  const SizedBox(height: 20),
                                  _AnimatedDateSelector(
                                    key: UniqueKey(),
                                  ), // Use the new self-animating widget
                                  const SizedBox(height: 20),
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
          Positioned(
            right: 20,
            bottom: 90,
            child: FloatingActionButton(
              heroTag: 'scan_product',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const ProductScreen(sku: '3760007337888'),
                  ),
                );
              },
              backgroundColor: Colors.blue,
              child: const Icon(Icons.qr_code_scanner, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesCard(UserModel? user, AppLocalizations l10n) {
    final currentPoints = user?.points ?? 0;
    final pendingPoints = user?.pendingPluxeePoints ?? 0;
    final availablePoints = user?.availablePoints ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF074F75), Color(0xFF1F9BD1)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F9BD1).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  l10n.totalPoints.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.stars_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    currentPoints.toString().replaceAllMapped(
                      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                      (Match m) => '${m[1]},',
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'pts',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              Material(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.pushNamed(context, '/rewards');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.card_giftcard,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.redeemYourPoints,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.currentBalance,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (pendingPoints > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.availablePoints(availablePoints),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.pendingPoints(pendingPoints),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
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
        _buildTotalPointsCard(l10n, user, redeemedRewards),
        _buildYearlyRankCard(context, l10n, user, leaderboard),
        _buildTopGoalCard(context, l10n, goal),
        _buildRecentBadgeCard(context, l10n, badge),
      ],
    );
  }

  Widget _buildTotalPointsCard(
    AppLocalizations l10n,
    UserModel user,
    RedeemedRewardsProvider redeemedRewards,
  ) {
    final allTimePoints = user.points + redeemedRewards.totalPointsSpent;
    return _buildDashboardCard(
      title: l10n.totalPoints,
      icon: Icons.stars_rounded,
      backgroundColor: const Color(0xFF10B981),
      contentColor: Colors.white,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF10B981), Color(0xFF059669)],
      ),
      mainContent: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '$allTimePoints',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'pts',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
        ],
      ),
      secondaryInfo: l10n.allTime,
    );
  }

  Widget _buildYearlyRankCard(
    BuildContext context,
    AppLocalizations l10n,
    UserModel user,
    LeaderboardProvider leaderboard,
  ) {
    final currentUserData = leaderboard.leaderboardData.firstWhere(
      (u) => u['userId'] == user.uid,
      orElse: () => {'rank': 'N/A'},
    );
    final rank = currentUserData['rank'];

    return _buildDashboardCard(
      title: l10n.yearlyRank,
      icon: Icons.emoji_events_rounded,
      backgroundColor: const Color(0xFFF59E0B),
      contentColor: Colors.white,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
      ),
      mainContent: Text(
        '#$rank',
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      secondaryInfo: l10n.outOfEmployees(leaderboard.leaderboardData.length),
    );
  }

  Widget _buildTopGoalCard(
    BuildContext context,
    AppLocalizations l10n,
    GoalProvider goalProvider,
  ) {
    Goal? topGoal;
    double maxProgress = -1;

    for (var goal in goalProvider.goals) {
      if (goal.userProgress != null && goal.targetValue > 0) {
        final progress = (goal.userProgress!.progressValue / goal.targetValue);
        if (progress > maxProgress) {
          maxProgress = progress;
          topGoal = goal;
        }
      }
    }

    return _buildDashboardCard(
      title: l10n.activeGoal,
      icon: Icons.track_changes_rounded,
      backgroundColor: const Color(0xFF6366F1),
      contentColor: Colors.white,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GoalsScreen()),
      ),
      mainContent: topGoal != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  topGoal.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: maxProgress.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Text(
              l10n.noActiveGoals,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
      secondaryInfo: topGoal != null
          ? '${(maxProgress * 100).toStringAsFixed(0)}% ${l10n.complete}'
          : '',
    );
  }

  Widget _buildRecentBadgeCard(
    BuildContext context,
    AppLocalizations l10n,
    BadgeProvider badgeProvider,
  ) {
    final awardedBadges = badgeProvider.badges
        .where((b) => b.isAwarded)
        .toList();
    awardedBadges.sort(
      (a, b) => b.userBadge!.awardedAt.compareTo(a.userBadge!.awardedAt),
    );
    final mostRecentBadge = awardedBadges.isNotEmpty
        ? awardedBadges.first
        : null;

    return _buildDashboardCard(
      title: l10n.latestBadge,
      icon: Icons.workspace_premium_rounded,
      backgroundColor: const Color(0xFFEF4444),
      contentColor: Colors.white,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BadgesScreen()),
      ),
      mainContent: mostRecentBadge != null
          ? Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.3),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Image.network(
                mostRecentBadge.badge.imageUrl,
                height: 48,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.workspace_premium,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            )
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
              ),
              child: const Icon(
                Icons.lock_outline,
                size: 32,
                color: Colors.white,
              ),
            ),
      secondaryInfo: mostRecentBadge?.badge.name ?? l10n.noBadgesEarned,
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required Widget mainContent,
    required String secondaryInfo,
    required IconData icon,
    required Color backgroundColor,
    required Color contentColor,
    Gradient? gradient,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? backgroundColor : null,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: backgroundColor.withOpacity(0.15),
            blurRadius: 40,
            offset: const Offset(0, 16),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          splashColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.05),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          color: contentColor.withOpacity(0.85),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: contentColor, size: 20),
                    ),
                  ],
                ),
                const Spacer(),
                Center(
                  child: DefaultTextStyle(
                    style: TextStyle(
                      color: contentColor,
                      fontFamily: 'Poppins',
                    ),
                    child: mainContent,
                  ),
                ),
                const Spacer(),
                Center(
                  child: Text(
                    secondaryInfo,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: contentColor.withOpacity(0.8),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
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

// New, self-contained widget for the date selector
class _AnimatedDateSelector extends StatefulWidget {
  const _AnimatedDateSelector({super.key});

  @override
  State<_AnimatedDateSelector> createState() => _AnimatedDateSelectorState();
}

class _AnimatedDateSelectorState extends State<_AnimatedDateSelector> {
  late final ScrollController _scrollController;
  late final List<Map<String, dynamic>> _days;
  final int _selectedDayIndex = 7; // Today is always the 8th item (index 7)
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // Safely schedule the animation to run after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerToIndex(_selectedDayIndex);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize here because it depends on context for l10n.
    if (!_isInitialized) {
      _generateDays();
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _generateDays() {
    final now = DateTime.now();
    final l10n = AppLocalizations.of(context)!;
    _days = [];

    for (int i = -7; i <= 6; i++) {
      final date = now.add(Duration(days: i));
      final dayNames = [
        '',
        l10n.mon,
        l10n.tue,
        l10n.wed,
        l10n.thu,
        l10n.fri,
        l10n.sat,
        l10n.sun,
      ];
      final label = dayNames[date.weekday];
      _days.add({'day': label, 'date': date.day.toString(), 'isToday': i == 0});
    }
  }

  void _centerToIndex(int index) {
    if (_scrollController.hasClients) {
      const itemWidth = 55.0;
      final viewportWidth = _scrollController.position.viewportDimension;
      final targetOffset =
          (index * itemWidth) - (viewportWidth / 2) + (itemWidth / 2);
      final maxScroll = _scrollController.position.maxScrollExtent;

      _scrollController.animateTo(
        targetOffset.clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: _days.length,
        itemBuilder: (context, index) {
          final day = _days[index];
          final isSelected = index == _selectedDayIndex;
          final isToday = day['isToday'] ?? false;

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () {
                // The selector is not interactive in this version, but tap could be added here.
              },
              child: Container(
                width: 45,
                height: 65,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: isSelected
                        ? Colors.black
                        : (isToday ? Colors.blue : Colors.grey.shade300),
                    width: isToday && !isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      day['day'],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey.shade600,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      day['date'],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
