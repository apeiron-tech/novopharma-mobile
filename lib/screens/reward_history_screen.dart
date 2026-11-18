import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:novopharma/controllers/redeemed_rewards_provider.dart';
import 'package:novopharma/design/design.dart';
import 'package:novopharma/models/redeemed_reward.dart';
import 'package:provider/provider.dart';

class RewardHistoryScreen extends StatelessWidget {
  const RewardHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: InkAppBar(
        title: 'Reward History',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: AppBackground(
        accent: Tone.amber,
        child: Consumer<RedeemedRewardsProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(child: CapsuleLoader());
            }

            if (provider.redeemedRewards.isEmpty) {
              return const EmptyState(
                icon: Icons.history_toggle_off_rounded,
                title: 'No Reward History',
                message: 'You have not redeemed any rewards yet.',
                tone: Tone.amber,
              );
            }

            return _RedeemedList(rewards: provider.redeemedRewards);
          },
        ),
      ),
    );
  }
}

/// The redeemed rewards, newest as the provider orders them. Holds the one
/// bit of state the list needs: whether its arrival has already played.
class _RedeemedList extends StatefulWidget {
  final List<RedeemedReward> rewards;
  const _RedeemedList({required this.rewards});

  @override
  State<_RedeemedList> createState() => _RedeemedListState();
}

class _RedeemedListState extends State<_RedeemedList> {
  bool _arrived = false;

  @override
  void initState() {
    super.initState();
    // Rows built after the first frame (scrolling back, rebuilds) appear in
    // place instead of animating again.
    WidgetsBinding.instance.addPostFrameCallback((_) => _arrived = true);
  }

  @override
  Widget build(BuildContext context) {
    final rewards = widget.rewards;
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        AppSpace.page,
        AppSpace.xl,
        AppSpace.page,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      itemCount: rewards.length,
      itemBuilder: (context, index) {
        final redeemed = rewards[index];
        final stagger = !_arrived && index < 8;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Entrance(
            delay: stagger ? Duration(milliseconds: 60 * index) : Duration.zero,
            duration: stagger ? AppMotion.slow : Duration.zero,
            child: SoftCard(
              radius: AppRadii.md,
              padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
              child: Row(
                children: [
                  const TintIcon(
                    icon: Icons.card_giftcard_rounded,
                    tone: Tone.amber,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          redeemed.rewardNameSnapshot,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(
                            size: 15.5,
                            weight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat.yMMMd().add_jm().format(
                            redeemed.redeemedAt,
                          ),
                          style: AppText.label(size: 12.5, letterSpacing: 0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '-${redeemed.pointsSpent} pts',
                    style: AppText.display(
                      size: 18,
                      color: AppColors.coralDeep,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
