import 'package:flutter/material.dart';
import 'package:novopharma/controllers/badge_provider.dart';
import 'package:novopharma/design/design.dart';
import 'package:novopharma/models/badge.dart' as models;
import 'package:novopharma/models/reward.dart' as models_reward;
import 'package:novopharma/widgets/badge_card.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

class BadgesScreen extends StatefulWidget {
  final String? initialBadgeId;
  const BadgesScreen({super.key, this.initialBadgeId});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  bool _initialBadgeHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BadgeProvider>().refreshBadges();
    });
  }

  void _checkInitialBadge(BadgeProvider provider) {
    if (_initialBadgeHandled || widget.initialBadgeId == null || provider.isLoading) {
      return;
    }

    final badgeInfo = provider.badges.firstWhereOrNull(
      (b) => b.badge.id == widget.initialBadgeId,
    );

    if (badgeInfo != null) {
      _initialBadgeHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showBadgeDetails(context, badgeInfo);
        }
      });
    } else {
      // If not found yet, maybe it will be in next update? 
      // But usually provider.isLoading = false means we have everything.
      _initialBadgeHandled = true; 
    }
  }

  /// "BADGES" -> "Badges". Leaves mixed-case strings alone.
  String _sentenceCase(String value) {
    if (value.isEmpty || value != value.toUpperCase()) return value;
    return value[0] + value.substring(1).toLowerCase();
  }

  void _showBadgeDetails(BuildContext context, BadgeDisplayInfo badgeInfo) {
    final l10n = AppLocalizations.of(context)!;
    final models.Badge badge = badgeInfo.badge;
    final models.AcquisitionRules? rules = badge.acquisitionRules;

    // Calculate progress details
    final badgesLeft = badge.maxWinners - badge.winnerCount;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return _SheetGlass(
              child: Column(
                children: [
                  // Handle
                  const _SheetHandle(),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: EdgeInsets.fromLTRB(
                        22,
                        8,
                        22,
                        24 + MediaQuery.paddingOf(context).bottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badge Image & Title
                          Center(
                            child: Column(
                              children: [
                                Entrance(
                                  offset: Offset.zero,
                                  scaleFrom: 0.82,
                                  child: BadgeDome(
                                    imageUrl: badge.imageUrl,
                                    earned: badgeInfo.isAwarded,
                                    size: 132,
                                    progress:
                                        !badgeInfo.isAwarded &&
                                            badgeInfo.progress > 0 &&
                                            badgeInfo.progress < 1
                                        ? badgeInfo.progress
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  badge.name,
                                  style: AppText.display(size: 24),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  badge.description,
                                  style: AppText.body(size: 15, height: 1.5),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Status Badge
                          if (badgeInfo.isAwarded)
                            _buildAwardedStatus(badgeInfo, context)
                          else
                            _buildProgressStatus(badgeInfo, rules),

                          const SizedBox(height: 24),

                          // Badge Info Cards
                          _buildInfoGrid(badge, rules, badgesLeft, context),

                          const SizedBox(height: 24),

                          // View Rules Button
                          _buildRulesButton(context, badge, rules, l10n),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAwardedStatus(BadgeDisplayInfo badgeInfo, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SoftCard(
      gradient: AppGradients.mint,
      radius: AppRadii.md,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.ink,
            size: 32,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.badgeEarned,
                  style: AppText.display(size: 18, color: AppColors.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.awardedOn(
                    DateFormat.yMMMd().format(badgeInfo.userBadge!.awardedAt),
                  ),
                  style: AppText.body(
                    size: 14,
                    weight: FontWeight.w500,
                    color: AppColors.ink.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStatus(
    BadgeDisplayInfo badgeInfo,
    models.AcquisitionRules? rules,
  ) {
    if (rules == null) return const SizedBox.shrink();

    final progressPercent = badgeInfo.progress * 100;
    final currentValue = (badgeInfo.progress * rules.targetValue);

    return Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return SoftCard(
          radius: AppRadii.md,
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.progress, style: AppText.display(size: 16)),
                  Text(
                    '${progressPercent.toStringAsFixed(0)}%',
                    style: AppText.display(
                      size: 20,
                      color: AppColors.amberDeep,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: CapsuleProgress(
                  value: badgeInfo.progress,
                  tone: Tone.amber,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatValue(currentValue, rules.metric),
                    style: AppText.display(size: 14),
                  ),
                  Text(
                    _formatValue(rules.targetValue, rules.metric),
                    style: AppText.display(
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatValue(double value, String metric) {
    if (metric == 'revenue') {
      return '${value.toStringAsFixed(2)} TND';
    } else if (metric == 'points') {
      return '${value.toStringAsFixed(0)} pts';
    } else {
      return value.toStringAsFixed(0);
    }
  }

  Widget _buildInfoGrid(
    models.Badge badge,
    models.AcquisitionRules? rules,
    int badgesLeft,
    BuildContext context,
  ) {
    if (rules == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final startDate = DateFormat.yMMMd().format(rules.timeframe.startDate);
    final endDate = DateFormat.yMMMd().format(rules.timeframe.endDate);

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildInfoCard(
                  Icons.emoji_events_rounded,
                  l10n.badgesLeft,
                  badgesLeft > 0 || badgesLeft == 0 ? '$badgesLeft' : '∞',
                  Tone.amber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  Icons.flag_rounded,
                  l10n.target,
                  _formatValue(rules.targetValue, rules.metric),
                  Tone.indigo,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Reward Card - handles different reward types
        if (badge.rewardType != null) _buildRewardCard(badge, context, l10n),
        _buildDateRangeCard(startDate, endDate, context),
      ],
    );
  }

  Widget _buildInfoCard(
    IconData icon,
    String label,
    String value,
    Tone tone,
  ) {
    return SoftCard(
      radius: AppRadii.md,
      shadow: false,
      tint: tone.tint,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: tone.deep, size: 28),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: AppText.display(size: 20),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppText.label(size: 12.5, letterSpacing: 0),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRewardCard(
    models.Badge badge,
    BuildContext context,
    AppLocalizations l10n,
  ) {
    if (badge.rewardType == 'reward' && badge.rewardId != null) {
      // For 'reward' type, we need to fetch the reward details
      return FutureBuilder<models_reward.Reward?>(
        future: _getRewardById(badge.rewardId!),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            final reward = snapshot.data!;
            return _buildRewardCardContent(
              Tone.mint, // Mint for rewards
              Icons.card_giftcard_rounded,
              l10n.rewardLabel,
              reward.name, // Display the reward name
              context,
            );
          } else {
            // If reward data is not available, show a loading state or fallback
            return _buildRewardCardContent(
              Tone.mint, // Mint for rewards
              Icons.card_giftcard_rounded,
              l10n.rewardLabel,
              'Loading...',
              context,
            );
          }
        },
      );
    } else {
      // For 'points' and 'custom' types, use the direct approach
      Tone cardTone;
      IconData iconData;
      String title;
      String value;

      switch (badge.rewardType) {
        case 'points':
          if (badge.points != null && badge.points! > 0) {
            cardTone = Tone.amber;
            iconData = Icons.stars_rounded;
            title = l10n.pointsLabel;
            value = '+${badge.points} pts';
          } else {
            // If rewardType is 'points' but no points, return empty container
            return const SizedBox.shrink();
          }
          break;
        case 'custom':
          cardTone = Tone.peach; // Peach for custom rewards
          iconData = Icons.card_giftcard_rounded;
          title = l10n.customRewardLabel;
          value = badge.customReward ?? 'Custom Reward';
          break;
        default:
          // If rewardType is not recognized, return empty container
          return const SizedBox.shrink();
      }

      return _buildRewardCardContent(
        cardTone,
        iconData,
        title,
        value,
        context,
      );
    }
  }

  Widget _buildRewardCardContent(
    Tone cardTone,
    IconData iconData,
    String title,
    String value,
    BuildContext context,
  ) {
    return Column(
      children: [
        SoftCard(
          radius: AppRadii.md,
          tint: cardTone.tint,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              BlisterIcon(icon: iconData, tone: cardTone, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.label(size: 13, letterSpacing: 0),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: AppText.display(size: 19, height: 1.15),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // Helper method to fetch reward by ID
  Future<models_reward.Reward?> _getRewardById(String rewardId) async {
    try {
      final rewardRef = FirebaseFirestore.instance
          .collection('rewards')
          .doc(rewardId);
      final rewardDoc = await rewardRef.get();

      if (rewardDoc.exists) {
        return models_reward.Reward.fromFirestore(rewardDoc);
      }
      return null;
    } catch (e) {
      print('Error fetching reward: $e');
      return null;
    }
  }

  Widget _buildDateRangeCard(
    String startDate,
    String endDate,
    BuildContext context,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return SoftCard(
      radius: AppRadii.md,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const TintIcon(
            icon: Icons.calendar_month_rounded,
            tone: Tone.indigo,
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.eventPeriod,
                  style: AppText.label(size: 12.5, letterSpacing: 0),
                ),
                const SizedBox(height: 4),
                Text(
                  '$startDate - $endDate',
                  style: AppText.display(size: 15, height: 1.2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesButton(
    BuildContext context,
    models.Badge badge,
    models.AcquisitionRules? rules,
    AppLocalizations l10n,
  ) {
    return PrimaryButton(
      label: l10n.viewRules,
      icon: Icons.arrow_forward_rounded,
      gradient: AppGradients.amber,
      glowColor: AppColors.amber,
      foreground: AppColors.ink,
      onPressed: () {
        Navigator.pop(context);
        _showBadgeRules(context, badge, rules);
      },
    );
  }

  void _showBadgeRules(
    BuildContext context,
    models.Badge badge,
    models.AcquisitionRules? rules,
  ) {
    if (rules == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BadgeRulesSheet(badge: badge, rules: rules),
    );
  }

  // The blister pack: three domes across on a phone, more on a tablet.
  static const _gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 140,
    crossAxisSpacing: 12.0,
    mainAxisSpacing: 12.0,
    childAspectRatio: 0.68,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: AppBackground(
        accent: Tone.amber,
        child: Consumer<BadgeProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return _buildPage(
                context,
                l10n,
                scrollable: false,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.page,
                      26,
                      AppSpace.page,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Shimmer(
                        child: GridView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: _gridDelegate,
                          itemCount: 9,
                          itemBuilder: (context, index) =>
                              const SkeletonBox(radius: AppRadii.md),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            // Check for initial badge detail trigger
            if (widget.initialBadgeId != null && !_initialBadgeHandled) {
              _checkInitialBadge(provider);
            }

            if (provider.badges.isEmpty) {
              return _buildPage(
                context,
                l10n,
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.military_tech_rounded,
                      title: l10n.noBadgesAvailable,
                      tone: Tone.amber,
                    ),
                  ),
                ],
              );
            }

            final awardedBadges = provider.badges
                .where((b) => b.isAwarded)
                .toList();
            final lockedBadges = provider.badges
                .where((b) => !b.isAwarded)
                .toList();

            return _buildPage(
              context,
              l10n,
              awardedCount: awardedBadges.length,
              totalCount: provider.badges.length,
              slivers: [
                _buildSectionHeader(
                  '${l10n.badgeAwarded} (${awardedBadges.length})',
                ),
                _buildGrid(awardedBadges, context),
                _buildSectionHeader(
                  '${l10n.badgeLocked} (${lockedBadges.length})',
                ),
                _buildGrid(lockedBadges, context),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.paddingOf(context).bottom + 28,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The ink hero followed by [slivers]. Every state of the screen goes
  /// through here so the hero stays put while the content below changes.
  Widget _buildPage(
    BuildContext context,
    AppLocalizations l10n, {
    required List<Widget> slivers,
    int? awardedCount,
    int? totalCount,
    bool scrollable = true,
  }) {
    return CustomScrollView(
      physics: scrollable ? null : const NeverScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _buildHero(context, l10n, awardedCount, totalCount),
        ),
        ...slivers,
      ],
    );
  }

  Widget _buildHero(
    BuildContext context,
    AppLocalizations l10n,
    int? awardedCount,
    int? totalCount,
  ) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final muted = Colors.white.withValues(alpha: 0.78);

    return InkHero(
      padding: const EdgeInsets.fromLTRB(AppSpace.page, 10, AppSpace.page, 26),
      child: Column(
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
                  _sentenceCase(l10n.badges),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.display(size: 26, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              const BlisterIcon(
                icon: Icons.military_tech_rounded,
                tone: Tone.amber,
                size: 44,
              ),
            ],
          ),
          if (awardedCount != null && totalCount != null) ...[
            const SizedBox(height: 20),
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
                      l10n.badgeAwarded,
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
                          value: awardedCount,
                          style: AppText.display(
                            size: 44,
                            color: Colors.white,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '/ $totalCount',
                          style: AppText.display(size: 22, color: muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: CapsuleProgress(
                        value: totalCount > 0 ? awardedCount / totalCount : 0.0,
                        tone: Tone.amber,
                        height: 10,
                        trackColor: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.page,
          26,
          AppSpace.page,
          14,
        ),
        child: Text(title, style: AppText.display(size: 20)),
      ),
    );
  }

  Widget _buildGrid(List<BadgeDisplayInfo> badges, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (badges.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
          child: SoftCard(
            radius: AppRadii.md,
            shadow: false,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const TintIcon(
                  icon: Icons.military_tech_rounded,
                  tone: Tone.amber,
                  size: 40,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    l10n.noBadgesInCategory,
                    style: AppText.body(
                      size: 14.5,
                      color: AppColors.textMuted,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
      sliver: SliverGrid(
        gridDelegate: _gridDelegate,
        delegate: SliverChildBuilderDelegate((context, index) {
          final badgeInfo = badges[index];
          return Pressable(
            onTap: () => _showBadgeDetails(context, badgeInfo),
            semanticLabel: badgeInfo.badge.name,
            child: BadgeCard(badgeInfo: badgeInfo),
          );
        }, childCount: badges.length),
      ),
    );
  }
}

/// The frosted pane of a draggable sheet: [GlassSheet]'s glass, without its
/// own layout, so a `DraggableScrollableSheet` can drive the scroll inside.
class _SheetGlass extends StatelessWidget {
  final Widget child;
  const _SheetGlass({required this.child});

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
        child: child,
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 5,
      margin: const EdgeInsets.only(top: 12, bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}

class _BadgeRulesSheet extends StatelessWidget {
  final models.Badge badge;
  final models.AcquisitionRules rules;

  const _BadgeRulesSheet({required this.badge, required this.rules});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return _SheetGlass(
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              const _SheetHandle(),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(
                    22,
                    10,
                    22,
                    24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const BlisterIcon(
                            icon: Icons.rule_rounded,
                            tone: Tone.amber,
                            size: 48,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              l10n.viewRules,
                              style: AppText.display(size: 22),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      _buildRuleSection(
                        Icons.track_changes_rounded,
                        l10n.metric,
                        _getMetricText(rules.metric, l10n),
                        Tone.indigo,
                      ),
                      const SizedBox(height: 12),
                      _buildRuleSection(
                        Icons.flag_rounded,
                        l10n.target,
                        _formatValue(rules.targetValue, rules.metric),
                        Tone.amber,
                      ),
                      const SizedBox(height: 12),
                      _buildScopeSection(l10n),
                      const SizedBox(height: 12),
                      _buildTimeframeSection(l10n),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRuleSection(
    IconData icon,
    String title,
    String value,
    Tone tone,
  ) {
    return SoftCard(
      radius: AppRadii.md,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          TintIcon(icon: icon, tone: tone, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.label(size: 13, letterSpacing: 0)),
                const SizedBox(height: 4),
                Text(value, style: AppText.display(size: 18, height: 1.15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeSection(AppLocalizations l10n) {
    return SoftCard(
      radius: AppRadii.md,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const TintIcon(
                icon: Icons.shopping_bag_rounded,
                tone: Tone.mint,
                size: 44,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(l10n.scope, style: AppText.display(size: 18)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (rules.scope.brands.isNotEmpty) ...[
            _buildScopeItem(l10n.brands, rules.scope.brands.join(', ')),
            const SizedBox(height: 12),
          ],
          if (rules.scope.categories.isNotEmpty) ...[
            _buildScopeItem(l10n.categories, rules.scope.categories.join(', ')),
            const SizedBox(height: 12),
          ],
          if (rules.scope.productIds.isNotEmpty)
            _ProductChipsWidget(productIds: rules.scope.productIds),
        ],
      ),
    );
  }

  Widget _buildScopeItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label(size: 13, letterSpacing: 0)),
        const SizedBox(height: 4),
        Text(value, style: AppText.body(size: 15, weight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildTimeframeSection(AppLocalizations l10n) {
    final startDate = DateFormat.yMMMd().format(rules.timeframe.startDate);
    final endDate = DateFormat.yMMMd().format(rules.timeframe.endDate);

    return SoftCard(
      radius: AppRadii.md,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const TintIcon(
            icon: Icons.calendar_month_rounded,
            tone: Tone.indigo,
            size: 44,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.eventPeriod,
                  style: AppText.label(size: 13, letterSpacing: 0),
                ),
                const SizedBox(height: 8),
                Text(startDate, style: AppText.display(size: 16)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 2,
                      color: AppColors.lineStrong,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.to,
                      style: AppText.label(size: 12, letterSpacing: 0),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 30,
                      height: 2,
                      color: AppColors.lineStrong,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(endDate, style: AppText.display(size: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getMetricText(String metric, AppLocalizations l10n) {
    switch (metric) {
      case 'points':
        return l10n.loyaltyPoints;
      case 'revenue':
        return l10n.totalRevenue;
      case 'quantity':
        return l10n.quantitySold;
      default:
        return metric;
    }
  }

  String _formatValue(double value, String metric) {
    if (metric == 'revenue') {
      return '${value.toStringAsFixed(2)} TND';
    } else if (metric == 'points') {
      return '${value.toStringAsFixed(0)} pts';
    } else {
      return value.toStringAsFixed(0);
    }
  }
}

// Widget to display product chips with expandable view
class _ProductChipsWidget extends StatefulWidget {
  final List<String> productIds;

  const _ProductChipsWidget({required this.productIds});

  @override
  State<_ProductChipsWidget> createState() => _ProductChipsWidgetState();
}

class _ProductChipsWidgetState extends State<_ProductChipsWidget> {
  bool _isExpanded = false;
  Map<String, String> _productNames = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProductNames();
  }

  Future<void> _fetchProductNames() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final Map<String, String> names = {};

      // Fetch product names in batches of 10 (Firestore whereIn limit)
      for (int i = 0; i < widget.productIds.length; i += 10) {
        final batch = widget.productIds.skip(i).take(10).toList();
        final snapshot = await firestore
            .collection('products')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (var doc in snapshot.docs) {
          names[doc.id] = doc.data()['name'] ?? 'Produit ${doc.id}';
        }
      }

      if (mounted) {
        setState(() {
          _productNames = names;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.products,
            style: AppText.label(size: 13, letterSpacing: 0),
          ),
          const SizedBox(height: 8),
          const Center(child: CapsuleLoader(size: 28)),
        ],
      );
    }

    final displayedProducts = _isExpanded
        ? widget.productIds
        : widget.productIds.take(3).toList();
    final hasMore = widget.productIds.length > 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.products, style: AppText.label(size: 13, letterSpacing: 0)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ...displayedProducts.map((productId) {
              final productName = _productNames[productId] ?? productId;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.indigoTint,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.inventory_2_rounded,
                      size: 16,
                      color: AppColors.indigoDeep,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        productName,
                        style: AppText.label(
                          size: 13,
                          color: AppColors.text,
                          letterSpacing: 0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (hasMore)
              Pressable(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                // Padded so the tap target reaches 44pt around a 33pt chip.
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.amberTint,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isExpanded
                              ? Icons.expand_less_rounded
                              : Icons.more_horiz_rounded,
                          size: 18,
                          color: AppColors.amberDeep,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isExpanded
                              ? l10n.showLess
                              : '+${widget.productIds.length - 3}',
                          style: AppText.label(
                            size: 13,
                            weight: FontWeight.w700,
                            color: AppColors.text,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
