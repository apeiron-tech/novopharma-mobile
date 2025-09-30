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
import 'package:novopharma/services/product_service.dart';
import 'package:novopharma/theme.dart';
import 'package:novopharma/widgets/dashboard_header.dart';
import 'package:novopharma/widgets/bottom_navigation_bar.dart';
import 'package:novopharma/widgets/rewards_fab_core.dart';
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
            bottom: 80,
            right: 30,
            left: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FloatingActionButton(
                  onPressed: () async {
                    final productService = ProductService();
                    final product = await productService.getProductBySku(
                      '3760007337888',
                    );
                    if (product != null && mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductScreen(sku: product.sku),
                        ),
                      );
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Product not found!')),
                      );
                    }
                  },
                  heroTag: 'scan_test_btn',
                  backgroundColor: Colors.blueAccent,
                  child: const Icon(Icons.qr_code_scanner),
                ),
                const RewardsFABCore(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesCard(UserModel? user, AppLocalizations l10n) {
    final currentPoints = user?.points ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(31, 26, 31, 36),
      decoration: BoxDecoration(
        color: LightModeColors.dashboardTealBlue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.totalPoints,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currentPoints.toString().replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (Match m) => '${m[1]},',
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.currentBalance,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
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
      icon: Icons.star_border,
      backgroundColor: const Color(0xFFA7E8E7),
      contentColor: const Color(0xFF004D40),
      mainContent: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '$allTimePoints',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 2),
          Text(
            'pts',
            style: TextStyle(
              fontSize: 14,
              color: const Color(0xFF004D40).withOpacity(0.8),
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
      icon: Icons.emoji_events_outlined,
      backgroundColor: const Color(0xFF67D6C4),
      contentColor: const Color(0xFF003D33),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
      ),
      mainContent: Text(
        '#$rank',
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
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
      icon: Icons.track_changes_outlined,
      backgroundColor: const Color(0xFF022E57),
      contentColor: Colors.white,
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: maxProgress.clamp(0.0, 1.0),
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ),
              ],
            )
          : Text(l10n.noActiveGoals, style: const TextStyle(fontSize: 14)),
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
      icon: Icons.shield_outlined,
      backgroundColor: const Color(0xFF2979FF),
      contentColor: Colors.white,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BadgesScreen()),
      ),
      mainContent: mostRecentBadge != null
          ? Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Image.network(
                mostRecentBadge.badge.imageUrl,
                height: 50,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.shield, size: 50, color: Colors.white),
              ),
            )
          : const Icon(Icons.lock_outline, size: 40),
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
    VoidCallback? onTap,
  }) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: contentColor.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(icon, color: contentColor, size: 20),
                ],
              ),
              const Spacer(),
              Center(
                child: DefaultTextStyle(
                  style: TextStyle(color: contentColor, fontFamily: 'Poppins'),
                  child: mainContent,
                ),
              ),
              const Spacer(),
              Center(
                child: Text(
                  secondaryInfo,
                  style: TextStyle(
                    fontSize: 12,
                    color: contentColor.withOpacity(0.7),
                  ),
                ),
              ),
            ],
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
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      day['date'],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontSize: 16,
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
