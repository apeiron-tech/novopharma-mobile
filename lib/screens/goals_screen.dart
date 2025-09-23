import 'package:flutter/material.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/controllers/goal_provider.dart';
import 'package:novopharma/screens/goal_details_screen.dart';
import 'package:novopharma/screens/quiz_list_screen.dart';
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

  void _onNavigateToQuizzes() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const QuizListScreen(),
      ),
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
          return CustomScrollView(
            slivers: [
              // Header
              SliverAppBar(
                pinned: true,
                expandedHeight: 120,
                backgroundColor: const Color(0xFFF6F8FB),
                elevation: 0,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFF6F8FB),
                          Color(0xFFFFFFFF),
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.goals,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF102132),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Consumer<GoalProvider>(
                              builder: (context, goalProvider, child) {
                                final goalCount = goalProvider.goals.length;
                                return Text(
                                  'You have $goalCount active goals.',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF4A5568),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Content
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    // Quizzes Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildQuizNavigationCard(l10n),
                    ),
                    const SizedBox(height: 24),
                    // Active Goals Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        l10n.activeGoals,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF102132),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Goals Slider
                    if (goalProvider.isLoading)
                      const SizedBox(
                        height: 280,
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF1F9BD1),
                            ),
                          ),
                        ),
                      )
                    else if (goalProvider.goals.isEmpty)
                      _buildEmptyState(l10n)
                    else
                      SizedBox(
                        height: 240, // Adjusted height for the new card design
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
                            return GoalCard(
                              goal: goal,
                              progress: goal.userProgress,
                              onTap: () => _onGoalCardTap(goal),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                    // Page Indicator
                    if (goalProvider.goals.isNotEmpty)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          goalProvider.goals.length,
                          (index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: _currentPage == index ? 20 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? const Color(0xFF1F9BD1)
                                  : const Color(0xFF94A3B8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(
                        height: 100), // Bottom padding for navbar
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuizNavigationCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1F9BD1),
            const Color(0xFF1F9BD1).withAlpha(204),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F9BD1).withAlpha(76),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                '💡',
                style: TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.quizzes,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.testYourKnowledge,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withAlpha(230),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _onNavigateToQuizzes,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1F9BD1),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(100, 44),
            ),
            child: Text(
              l10n.viewAll,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Container(
      height: 280,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF102040).withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.emoji_events_outlined,
            size: 64,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noActiveGoals,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A5568),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.checkBackSoon,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF94A3B8),
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
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF94A3B8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              goal.title,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF102132),
                              ),
                              overflow: TextOverflow.visible,
                              softWrap: true,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F9BD1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${progressPercent.toStringAsFixed(0)}% ${l10n.complete}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        goal.description,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF4A5568),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Progress section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F8FB),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.progressDetails,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF102132),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  size: 16,
                                  color: Color(0xFF4A5568),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    goal.timeRemaining,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF4A5568),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.military_tech,
                                  size: 16,
                                  color: Color(0xFF4A5568),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    goal.rewardText,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF4A5568),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(context); // Close the bottom sheet
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => GoalDetailsScreen(goal: goal),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFF1F9BD1),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                minimumSize: const Size(0, 52),
                              ),
                              child: Text(
                                l10n.viewRules,
                                style: const TextStyle(
                                  color: Color(0xFF1F9BD1),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1F9BD1),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                minimumSize: const Size(0, 52),
                              ),
                              child: Text(
                                l10n.trackProgress,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
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
}