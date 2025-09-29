import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:novopharma/controllers/redeemed_rewards_provider.dart';
import 'package:novopharma/theme.dart';
import 'package:provider/provider.dart';

class RewardHistoryScreen extends StatelessWidget {
  const RewardHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF102132)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Reward History',
          style: TextStyle(
            color: Color(0xFF102132),
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: Consumer<RedeemedRewardsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.redeemedRewards.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No Reward History',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF4A5568)),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'You have not redeemed any rewards yet.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.redeemedRewards.length,
            itemBuilder: (context, index) {
              final redeemed = provider.redeemedRewards[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                shadowColor: Colors.black.withOpacity(0.05),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: LightModeColors.novoPharmaBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.card_giftcard, color: LightModeColors.novoPharmaBlue),
                  ),
                  title: Text(
                    redeemed.rewardNameSnapshot,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF102132)),
                  ),
                  subtitle: Text(
                    DateFormat.yMMMd().add_jm().format(redeemed.redeemedAt),
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                  trailing: Text(
                    '-${redeemed.pointsSpent} pts',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
