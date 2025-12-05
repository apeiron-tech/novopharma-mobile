import 'package:flutter/material.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/controllers/goal_provider.dart';
import 'package:novopharma/screens/goal_details_screen.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/models/goal.dart';
import '../widgets/goal_card.dart';
import '../widgets/bottom_navigation_bar.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.86);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.appAuthState == AppAuthState.authenticatedActive) {
        Provider.of<GoalProvider>(context, listen: false).fetchGoals();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onGoalCardTap(Goal goal) {
    _showGoalBottomSheet(goal);
  }

  void _showGoalBottomSheet(Goal goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GoalBottomSheet(goal: goal),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BottomNavigationScaffoldWrapper(
      currentIndex: 1,
      onTap: (index) {},
      child: Consumer<GoalProvider>(
        builder: (context, goalProvider, child) {
          return Container(
            color: Colors.white,
            child: CustomScrollView(
              slivers: [
                // Enhanced Modern Header
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 160,
                  backgroundColor: Colors.white,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.grey.shade50, Colors.white],
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFF1F9BD1),
                                          Color(0xFF1887B8),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(
                                            0xFF1F9BD1,
                                          ).withValues(alpha: 0.35),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                          spreadRadius: 0,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.flag_rounded,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.goals,
                                          style: const TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF1F2937),
                                            letterSpacing: -0.8,
                                            height: 1.1,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Consumer<GoalProvider>(
                                          builder:
                                              (context, goalProvider, child) {
                                                final goalCount =
                                                    goalProvider.goals.length;
                                                return Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 6,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFF1F9BD1,
                                                    ).withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    border: Border.all(
                                                      color: const Color(
                                                        0xFF1F9BD1,
                                                      ).withValues(alpha: 0.2),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    l10n.activeGoalsCount(
                                                      goalCount,
                                                    ),
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      color: Color(0xFF1F9BD1),
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      letterSpacing: 0.3,
                                                    ),
                                                  ),
                                                );
                                              },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Enhanced Content Section
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),
                      // Active Goals Section Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF1F9BD1,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.military_tech_rounded,
                                size: 20,
                                color: Color(0xFF1F9BD1),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              l10n.activeGoals,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1F2937),
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Enhanced Goals Slider
                      if (goalProvider.isLoading)
                        Container(
                          height: 260,
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF1F9BD1),
                              ),
                              strokeWidth: 3,
                            ),
                          ),
                        )
                      else if (goalProvider.goals.isEmpty)
                        _buildEmptyState(l10n)
                      else
                        SizedBox(
                          height: 260,
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: goalProvider.goals.length,
                            onPageChanged: (page) {
                              setState(() {
                                _currentPage = page;
                              });
                            },
                            itemBuilder: (context, index) {
                              final goal = goalProvider.goals[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: GoalCard(
                                  goal: goal,
                                  progress: goal.userProgress,
                                  onTap: () => _onGoalCardTap(goal),
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 20),
                      // Enhanced Page Indicator
                      if (goalProvider.goals.isNotEmpty)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            goalProvider.goals.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: _currentPage == index ? 24 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                gradient: _currentPage == index
                                    ? const LinearGradient(
                                        colors: [
                                          Color(0xFF1F9BD1),
                                          Color(0xFF1887B8),
                                        ],
                                      )
                                    : null,
                                color: _currentPage != index
                                    ? Colors.grey.shade300
                                    : null,
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: _currentPage == index
                                    ? [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF1F9BD1,
                                          ).withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 100), // Bottom padding for navbar
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Container(
      height: 300,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.grey.shade50],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1F9BD1).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_outlined,
              size: 64,
              color: Color(0xFF1F9BD1),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.noActiveGoals,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              l10n.checkBackSoon,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GoalBottomSheet extends StatelessWidget {
  final Goal goal;

  const GoalBottomSheet({super.key, required this.goal});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final progress = goal.userProgress;
    final progressPercent = progress != null && goal.targetValue > 0
        ? (progress.progressValue / goal.targetValue * 100).clamp(0, 100)
        : 0.0;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Enhanced Handle
              Container(
                margin: const EdgeInsets.only(top: 16, bottom: 12),
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Enhanced Header
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              goal.title,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1F2937),
                                letterSpacing: -0.5,
                                height: 1.2,
                              ),
                              overflow: TextOverflow.visible,
                              softWrap: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: progressPercent >= 100
                                    ? [
                                        const Color(0xFF22C55E),
                                        const Color(0xFF16A34A),
                                      ]
                                    : [
                                        const Color(0xFF1F9BD1),
                                        const Color(0xFF1887B8),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (progressPercent >= 100
                                              ? const Color(0xFF22C55E)
                                              : const Color(0xFF1F9BD1))
                                          .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (progressPercent >= 100)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                if (progressPercent >= 100)
                                  const SizedBox(width: 6),
                                Text(
                                  '${progressPercent.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        goal.description,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Enhanced Progress Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.grey.shade50, Colors.white],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF1F9BD1,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.analytics_rounded,
                                    size: 18,
                                    color: Color(0xFF1F9BD1),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  l10n.progressDetails,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1F2937),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildInfoRow(
                              Icons.schedule_rounded,
                              goal.getTimeRemaining(l10n),
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              Icons.military_tech_rounded,
                              goal.rewardText,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Enhanced Action Button
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF1F9BD1), Color(0xFF1887B8)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF1F9BD1,
                              ).withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      GoalDetailsScreen(goal: goal),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    l10n.viewRules,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF1F9BD1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF1F9BD1)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
