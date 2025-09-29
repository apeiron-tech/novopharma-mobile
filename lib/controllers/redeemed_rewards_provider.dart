import 'dart:async';
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
  StreamSubscription<List<RedeemedReward>>? _redeemedRewardsSubscription;

  RedeemedRewardsProvider(this._authProvider) {
    if (_authProvider.userProfile != null) {
      _subscribeToRedeemedRewards();
    }
  }

  List<RedeemedReward> get redeemedRewards => _redeemedRewards;
  bool get isLoading => _isLoading;
  int get totalPointsSpent => _totalPointsSpent;

  void update(AuthProvider authProvider) {
    if (authProvider.userProfile?.uid != _authProvider.userProfile?.uid) {
      _authProvider = authProvider;
      _subscribeToRedeemedRewards();
    }
  }

  void _subscribeToRedeemedRewards() {
    _isLoading = true;
    notifyListeners();

    _redeemedRewardsSubscription?.cancel();
    if (_authProvider.userProfile == null) {
      _redeemedRewards = [];
      _totalPointsSpent = 0;
      _isLoading = false;
      notifyListeners();
      return;
    }

    _redeemedRewardsSubscription = _redeemedRewardService
        .getRedeemedRewards(_authProvider.userProfile!.uid)
        .listen((rewards) {
      _redeemedRewards = rewards;
      _totalPointsSpent = rewards.fold(0, (sum, reward) => sum + reward.pointsSpent);
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
      print('Error in redeemed rewards stream: $error');
      _isLoading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _redeemedRewardsSubscription?.cancel();
    super.dispose();
  }
}
