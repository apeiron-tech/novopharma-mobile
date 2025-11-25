import 'package:flutter/foundation.dart';
import 'package:novopharma/models/reward.dart';
import 'package:novopharma/models/user_model.dart';
import 'package:novopharma/services/redeemed_reward_service.dart';
import 'package:novopharma/services/rewards_service.dart';

class RewardsController extends ChangeNotifier {
  final RewardService _rewardsService = RewardService();
  final RedeemedRewardService _redeemedRewardService = RedeemedRewardService();

  List<Reward> _rewards = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Reward> get rewards => _rewards;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadRewards() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _rewards = await _rewardsService.getRewards();
    } catch (e) {
      _error = 'Failed to load rewards. Please try again.';
      debugPrint('Error loading rewards: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> redeemReward({
    required String rewardId,
    required UserModel currentUser,
  }) async {
    final reward = _rewards.firstWhere((r) => r.id == rewardId);

    if (currentUser.points < reward.pointsCost) {
      return 'Insufficient points';
    }
    if (reward.stock <= 0) {
      return 'Reward out of stock';
    }

    try {
      await _redeemedRewardService.redeemReward(
        userId: currentUser.uid,
        userNameSnapshot: currentUser.name,
        rewardId: reward.id,
        rewardNameSnapshot: reward.name,
        pointsSpent: reward.pointsCost,
      );

      // The user's points and redeemed rewards list will update automatically via streams.
      // We just need to reload the available rewards to get the new stock count.
      await loadRewards();

      return null; // Success
    } catch (e) {
      debugPrint('Error redeeming reward: $e');
      return 'An error occurred during redemption.';
    }
  }
}
