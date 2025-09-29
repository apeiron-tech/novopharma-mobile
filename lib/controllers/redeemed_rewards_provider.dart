import 'package:flutter/foundation.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/models/redeemed_reward.dart';
import 'package:novopharma/services/redeemed_reward_service.dart';

class RedeemedRewardsProvider with ChangeNotifier {
  final RedeemedRewardService _redeemedRewardService = RedeemedRewardService();
  AuthProvider _authProvider;

  List<RedeemedReward> _redeemedRewards = [];
  bool _isLoading = false;
  int _totalPointsSpent = 0;

  RedeemedRewardsProvider(this._authProvider) {
    if (_authProvider.userProfile != null) {
      fetchRedeemedRewards();
    }
  }

  List<RedeemedReward> get redeemedRewards => _redeemedRewards;
  bool get isLoading => _isLoading;
  int get totalPointsSpent => _totalPointsSpent;

  void update(AuthProvider authProvider) {
    if (authProvider.userProfile?.uid != _authProvider.userProfile?.uid) {
      _authProvider = authProvider;
      if (_authProvider.userProfile != null) {
        fetchRedeemedRewards();
      } else {
        _redeemedRewards = [];
        _totalPointsSpent = 0;
        notifyListeners();
      }
    }
  }

  Future<void> fetchRedeemedRewards() async {
    if (_authProvider.userProfile == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      _redeemedRewards = await _redeemedRewardService.getRedeemedRewards(_authProvider.userProfile!.uid);
      _totalPointsSpent = _redeemedRewards.fold(0, (sum, reward) => sum + reward.pointsSpent);
    } catch (e) {
      print('Error fetching redeemed rewards: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
