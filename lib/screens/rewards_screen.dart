import 'package:flutter/material.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/design/design.dart';
import 'package:novopharma/models/reward.dart';
import 'package:novopharma/controllers/rewards_controller.dart';
import 'package:novopharma/screens/reward_history_screen.dart';
import 'package:novopharma/controllers/redeemed_rewards_provider.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // The RedeemedRewardsProvider is already updated by the proxy in main.dart
      // We just need to load the list of available rewards.
      Provider.of<RewardsController>(context, listen: false).loadRewards();
    });
  }

  void _showRedeemDialog(BuildContext context, Reward reward) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final rewardsController = Provider.of<RewardsController>(
      context,
      listen: false,
    );
    final currentUser = authProvider.userProfile;
    final l10n = AppLocalizations.of(context)!;

    if (currentUser == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (ctx) => GlassSheet(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(reward.name, style: AppText.display(size: 22)),
                const SizedBox(height: 8),
                Text(
                  reward.description,
                  style: AppText.body(size: 14.5, color: AppColors.textMuted),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.amberTint.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  child: Row(
                    children: [
                      const BlisterIcon(
                        icon: Icons.stars_rounded,
                        tone: Tone.amber,
                        size: 40,
                        glow: false,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${reward.pointsCost} pts',
                            style: AppText.display(size: 30),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: SecondaryButton(
                        label: l10n.cancel,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: PrimaryButton.coral(
                        label: l10n.redeem,
                        height: 52,
                        onPressed:
                            (currentUser.points >= reward.pointsCost &&
                                reward.stock > 0)
                            ? () async {
                                final error = await rewardsController
                                    .redeemReward(
                                      rewardId: reward.id,
                                      currentUser: currentUser,
                                    );

                                if (mounted) {
                                  Navigator.pop(ctx);
                                  if (error == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Successfully redeemed ${reward.name}!',
                                        ),
                                        backgroundColor: AppColors.mintDeep,
                                      ),
                                    );
                                    celebrate(this.context);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(error),
                                        backgroundColor: AppColors.coralDeep,
                                      ),
                                    );
                                  }
                                }
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// "POINTS TOTAUX" -> "Points totaux". The label comes shouting from the
  /// translations; the design speaks in sentence case.
  String _sentenceCase(String value) {
    if (value.isEmpty) return value;
    return value.substring(0, 1).toUpperCase() +
        value.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final media = MediaQuery.of(context);
    final maxWidth = media.size.width > 600 ? 640.0 : double.infinity;

    Widget centered(Widget child) => Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        );

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: AppBackground(
        accent: Tone.amber,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Consumer2<AuthProvider, RedeemedRewardsProvider>(
                builder:
                    (context, authProvider, redeemedRewardsProvider, child) {
                      final currentUser = authProvider.userProfile;
                      final currentPoints = currentUser?.points ?? 0;
                      final spentPoints =
                          redeemedRewardsProvider.totalPointsSpent;
                      final allTimePoints = currentPoints + spentPoints;

                      return InkHero(
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
                                child: Row(
                                  children: [
                                    GlassIconButton(
                                      icon: Icons.arrow_back_rounded,
                                      tooltip: MaterialLocalizations.of(
                                        context,
                                      ).backButtonTooltip,
                                      onTap: () => Navigator.pop(context),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        l10n.rewardsAndRedeem,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.display(
                                          size: 20,
                                          color: Colors.white,
                                          height: 1.12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 26),
                              Entrance(
                                delay: const Duration(milliseconds: 100),
                                scaleFrom: 0.96,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _sentenceCase(l10n.totalPoints),
                                      style: AppText.label(
                                        size: 14,
                                        letterSpacing: 0,
                                        color: Colors.white.withValues(
                                          alpha: 0.78,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: CountUp(
                                        value: currentPoints,
                                        style: AppText.display(
                                          size: 64,
                                          weight: FontWeight.w800,
                                          color: Colors.white,
                                          height: 1.0,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              Entrance(
                                delay: const Duration(milliseconds: 180),
                                child: SoftCard(
                                  style: GlassStyle.dark,
                                  blur: Glass.frost,
                                  radius: AppRadii.md,
                                  shadow: false,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.emoji_events_rounded,
                                        color: AppColors.amber,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          l10n.allTimeRewardPoints(
                                            formatPoints(allTimePoints),
                                          ),
                                          style: AppText.body(
                                            size: 14,
                                            weight: FontWeight.w600,
                                            color: Colors.white,
                                            height: 1.25,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Entrance(
                                delay: const Duration(milliseconds: 240),
                                child: _HeroLink(
                                  icon: Icons.history_rounded,
                                  label: l10n.viewRewardPointsHistory,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const RewardHistoryScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
              ),
            ),
            Consumer<RewardsController>(
              builder: (context, controller, child) {
                if (controller.isLoading && controller.rewards.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CapsuleLoader()),
                  );
                }
                if (controller.error != null) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.error_outline_rounded,
                      title: controller.error!,
                      tone: Tone.coral,
                    ),
                  );
                }
                if (controller.rewards.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.card_giftcard_rounded,
                      title: l10n.noRewardsAvailable,
                      tone: Tone.amber,
                    ),
                  );
                }

                return SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpace.page,
                      24,
                      AppSpace.page,
                      media.padding.bottom + 24,
                    ),
                    child: centered(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.redeemYourPoints,
                            style: AppText.display(size: 22),
                          ),
                          const SizedBox(height: 16),
                          GridView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                  mainAxisExtent: 256,
                                ),
                            itemCount: controller.rewards.length,
                            itemBuilder: (context, index) {
                              final reward = controller.rewards[index];
                              return Entrance.staggered(
                                index: index,
                                base: const Duration(milliseconds: 300),
                                child: _RewardCard(
                                  reward: reward,
                                  onTap: () =>
                                      _showRedeemDialog(context, reward),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A quiet action on the ink hero: a clear glass pill whose label may wrap,
/// for links too long for a button.
class _HeroLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HeroLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Glass(
        style: GlassStyle.dark,
        shadow: false,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        padding: const EdgeInsets.fromLTRB(16, 13, 10, 13),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 26),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(
                    size: 14.5,
                    weight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One reward in the catalogue: its picture under glass, what it costs, and
/// whether any are left.
class _RewardCard extends StatelessWidget {
  final Reward reward;
  final VoidCallback onTap;

  const _RewardCard({required this.reward, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final inStock = reward.stock > 0;
    const placeholder = ColoredBox(
      color: AppColors.amberTint,
      child: Center(
        child: Icon(
          Icons.card_giftcard_rounded,
          size: 40,
          color: AppColors.amberDeep,
        ),
      ),
    );

    return SoftCard(
      padding: EdgeInsets.zero,
      radius: AppRadii.md,
      onTap: onTap,
      semanticLabel: reward.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 112,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (reward.imageUrl.isNotEmpty)
                  Image.network(
                    reward.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => placeholder,
                  )
                else
                  placeholder,
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.ink.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      '${reward.pointsCost} pts',
                      style: AppText.display(
                        size: 13,
                        color: Colors.white,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reward.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.display(size: 15, height: 1.15),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      reward.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(
                        size: 12.5,
                        color: AppColors.textMuted,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TonePill(
                    label: 'Stock: ${reward.stock}',
                    tone: inStock ? Tone.mint : Tone.coral,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
