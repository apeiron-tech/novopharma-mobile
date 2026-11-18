import 'package:flutter/material.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/controllers/goal_provider.dart';
import 'package:novopharma/design/design.dart';
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

class _GoalsScreenState extends State<GoalsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.appAuthState == AppAuthState.authenticatedActive) {
        Provider.of<GoalProvider>(context, listen: false).fetchGoals();
      }
    });
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
          final goals = goalProvider.goals;
          return SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Ink hero: how many objectives, how many are done.
                InkHero(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.page,
                    10,
                    AppSpace.page,
                    26,
                  ),
                  child: _buildHero(l10n, goalProvider),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.page,
                    24,
                    AppSpace.page,
                    14,
                  ),
                  child: SectionHeader(title: l10n.activeGoals),
                ),
                if (goalProvider.isLoading)
                  const SkeletonList(
                    count: 3,
                    itemHeight: 176,
                    padding: EdgeInsets.symmetric(horizontal: AppSpace.page),
                  )
                else if (goals.isEmpty)
                  _buildEmptyState(l10n)
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.page,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var index = 0; index < goals.length; index++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Entrance.staggered(
                              index: index,
                              base: const Duration(milliseconds: 200),
                              child: GoalCard(
                                goal: goals[index],
                                progress: goals[index].userProgress,
                                onTap: () => _onGoalCardTap(goals[index]),
                              ),
                            ),
                          ),
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

  Widget _buildHero(AppLocalizations l10n, GoalProvider goalProvider) {
    final goals = goalProvider.goals;
    final goalCount = goals.length;
    final completedCount = goals
        .where((goal) => goal.userProgress?.status == 'completed')
        .length;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final muted = Colors.white.withValues(alpha: 0.78);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (canPop) ...[
              GlassIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onTap: () => Navigator.maybePop(context),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                l10n.goals,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.display(size: 26, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            const BlisterIcon(icon: Icons.flag_rounded, tone: Tone.coral, size: 44),
          ],
        ),
        if (!goalProvider.isLoading) ...[
          const SizedBox(height: 14),
          Text(
            l10n.activeGoalsCount(goalCount),
            style: AppText.body(
              size: 14.5,
              color: Colors.white.withValues(alpha: 0.86),
            ),
          ),
        ],
        if (!goalProvider.isLoading && goals.isNotEmpty) ...[
          const SizedBox(height: 18),
          Entrance(
            delay: const Duration(milliseconds: 100),
            scaleFrom: 0.96,
            child: SoftCard(
              style: GlassStyle.dark,
              blur: Glass.frost,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.progress,
                    style: AppText.label(
                      size: 12.5,
                      color: muted,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      CountUp(
                        value: completedCount,
                        style: AppText.display(
                          size: 40,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '/ $goalCount',
                        style: AppText.display(size: 22, color: muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // One capsule per objective, filled as far as it has got.
                  SizedBox(
                    width: double.infinity,
                    child: _buildProgressStrip(goals),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProgressStrip(List<Goal> goals) {
    double fractionOf(Goal goal) {
      final current = goal.userProgress?.progressValue ?? 0;
      return goal.targetValue > 0
          ? (current / goal.targetValue).clamp(0.0, 1.0)
          : 0.0;
    }

    final track = Colors.white.withValues(alpha: 0.16);

    // Too many to tell apart: fall back to a single bar of the average.
    if (goals.length > 10) {
      final average =
          goals.map(fractionOf).reduce((a, b) => a + b) / goals.length;
      return CapsuleProgress(
        value: average,
        tone: Tone.mint,
        height: 10,
        trackColor: track,
      );
    }

    return Row(
      children: [
        for (var i = 0; i < goals.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: CapsuleProgress(
              value: goals[i].userProgress?.status == 'completed'
                  ? 1.0
                  : fractionOf(goals[i]),
              tone: goals[i].userProgress?.status == 'completed'
                  ? Tone.mint
                  : Tone.coral,
              height: 10,
              trackColor: track,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return EmptyState(
      icon: Icons.flag_rounded,
      title: l10n.noActiveGoals,
      message: l10n.checkBackSoon,
      tone: Tone.coral,
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
    final Tone tone = progressPercent >= 100 ? Tone.mint : Tone.coral;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return _GoalSheetPane(
          child: SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              22,
              6,
              22,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and how far along
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        goal.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.display(size: 22, height: 1.15),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TonePill(
                      label: '${progressPercent.toStringAsFixed(0)}%',
                      tone: tone,
                      icon: progressPercent >= 100
                          ? Icons.check_circle_rounded
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: CapsuleProgress(
                    value: progressPercent / 100,
                    tone: tone,
                    height: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  goal.description,
                  style: AppText.body(size: 15.5, height: 1.5),
                ),
                const SizedBox(height: 22),
                // Progress details
                SoftCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const TintIcon(
                            icon: Icons.analytics_rounded,
                            tone: Tone.coral,
                            size: 38,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.progressDetails,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.display(size: 17),
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
                const SizedBox(height: 24),
                PrimaryButton.coral(
                  label: l10n.viewRules,
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GoalDetailsScreen(goal: goal),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        TintIcon(icon: icon, tone: Tone.amber, size: 34),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppText.body(size: 14.5, weight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// The frosted pane of a draggable sheet: [GlassSheet]'s glass, with its
/// content expanded so a `DraggableScrollableSheet` can drive the scroll.
class _GoalSheetPane extends StatelessWidget {
  final Widget child;
  const _GoalSheetPane({required this.child});

  @override
  Widget build(BuildContext context) {
    return Glass(
      blur: Glass.frost,
      shadow: false,
      tint: Colors.white,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadii.xl),
      ),
      // A light wash over the glass keeps long reading text legible when
      // the page behind the sheet is dimmed.
      child: ColoredBox(
        color: Colors.white.withValues(alpha: 0.5),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(top: 12, bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
