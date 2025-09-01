import 'package:flutter/foundation.dart';
import 'package:novopharma/models/redeemed_reward.dart';
import 'package:novopharma/models/reward.dart';
import 'package:novopharma/models/user_model.dart';
import 'package:novopharma/services/redeemed_reward_service.dart';
import 'package:novopharma/services/rewards_service.dart';

class RewardsController extends ChangeNotifier {
  final RewardService _rewardsService = RewardService();
  final RedeemedRewardService _redeemedRewardService = RedeemedRewardService();

  List<Reward> _rewards = [];
  List<RedeemedReward> _redeemedRewards = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Reward> get rewards => _rewards;
  List<RedeemedReward> get redeemedRewards => _redeemedRewards;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get totalSpentPoints {
    return _redeemedRewards.fold<int>(
      0,
      (sum, reward) => sum + reward.pointsSpent,
    );
  }

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

  Future<void> fetchRedeemedRewards(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();
      _redeemedRewards = await _redeemedRewardService.getRedeemedRewards(
        userId,
      );
    } catch (e) {
      _error = 'Failed to load redeemed rewards.';
      debugPrint('Error fetching redeemed rewards: $e');
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
      
      // Refresh the list of redeemed rewards after a successful redemption
      await fetchRedeemedRewards(currentUser.uid);

      // The user's points will update automatically via the AuthProvider stream.
      // Manually update the local stock for immediate UI feedback.
      final rewardIndex = _rewards.indexWhere((r) => r.id == rewardId);
      // This needs a copyWith method in the Reward model. Let's assume it exists or add it.
      // For now, we will just reload the rewards to show the new stock.
      await loadRewards();
      
      notifyListeners();
      return null; // Success
    } catch (e) {
      debugPrint('Error redeeming reward: $e');
      return 'An error occurred during redemption.';
    }
  }
}
