import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/theme.dart';
import 'package:novopharma/models/reward.dart';
import 'package:novopharma/controllers/rewards_controller.dart';
import 'package:novopharma/screens/reward_history_screen.dart';
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
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final rewardsController = Provider.of<RewardsController>(context, listen: false);
      
      rewardsController.loadRewards();
      if (authProvider.firebaseUser != null) {
        rewardsController.fetchRedeemedRewards(authProvider.firebaseUser!.uid);
      }
    });
  }

  void _showRedeemDialog(BuildContext context, Reward reward) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final rewardsController = Provider.of<RewardsController>(context, listen: false);
    final currentUser = authProvider.userProfile;
    final l10n = AppLocalizations.of(context)!;

    if (currentUser == null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(reward.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(reward.description, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Chip(
              label: Text('${reward.pointsCost} pts'),
              backgroundColor: LightModeColors.novoPharmaBlue,
              labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(l10n.cancel),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (currentUser.points >= reward.pointsCost && reward.stock > 0)
                        ? () async {
                            final error = await rewardsController.redeemReward(
                              rewardId: reward.id,
                              currentUser: currentUser,
                            );

                            if (mounted) {
                              Navigator.pop(ctx);
                              if (error == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Successfully redeemed ${reward.name}!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(error),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LightModeColors.novoPharmaBlue,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(l10n.redeem),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: LightModeColors.novoPharmaLightBlue,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2D2D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.rewardsAndRedeem,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          Consumer2<AuthProvider, RewardsController>(
            builder: (context, authProvider, rewardsController, child) {
              final currentUser = authProvider.userProfile;
              final currentPoints = currentUser?.points ?? 0;
              final spentPoints = rewardsController.totalSpentPoints;
              final allTimePoints = currentPoints + spentPoints;

              return Container(
                height: 250,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF2D2D2D), Color(0xFF4A4A4A)],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.totalPoints,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$currentPoints',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.allTimeRewardPoints(allTimePoints),
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RewardHistoryScreen()),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          side: const BorderSide(color: Colors.white, width: 1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          l10n.viewRewardPointsHistory,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: Consumer<RewardsController>(
              builder: (context, controller, child) {
                if (controller.isLoading && controller.rewards.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (controller.error != null) {
                  return Center(child: Text(controller.error!, style: const TextStyle(color: Colors.red)));
                }
                if (controller.rewards.isEmpty) {
                  return Center(child: Text(l10n.noRewardsAvailable));
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        l10n.redeemYourPoints,
                        style: GoogleFonts.montserrat(
                          color: LightModeColors.dashboardTextPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: controller.rewards.length,
                        itemBuilder: (context, index) {
                          final reward = controller.rewards[index];
                          return GestureDetector(
                            onTap: () => _showRedeemDialog(context, reward),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Stack(
                                    children: [
                                      Container(
                                        height: 120,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                          image: reward.imageUrl.isNotEmpty
                                              ? DecorationImage(image: NetworkImage(reward.imageUrl), fit: BoxFit.cover)
                                              : null,
                                        ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Chip(
                                          label: Text('${reward.pointsCost} pts'),
                                          backgroundColor: LightModeColors.novoPharmaBlue,
                                          labelStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(reward.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        Text(reward.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Stock: ${reward.stock}',
                                          style: TextStyle(
                                            color: reward.stock > 0 ? Colors.green.shade700 : Colors.red.shade700,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}