import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/models/redeemed_reward.dart';
import 'package:novopharma/services/redeemed_reward_service.dart';

class RedeemedRewardsProvider with ChangeNotifier {
  final RedeemedRewardService _redeemedRewardService = RedeemedRewardService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  AuthProvider _authProvider;

  List<RedeemedReward> _redeemedRewards = [];
  bool _isLoading = false;
  int _totalPointsSpent = 0;
  StreamSubscription<List<RedeemedReward>>? _redeemedRewardsSubscription;
  StreamSubscription<QuerySnapshot>? _pluxeeRedemptionSubscription;

  RedeemedRewardsProvider(this._authProvider) {
    if (_authProvider.userProfile != null) {
      _subscribeToRedeemedRewards();
      _subscribeToPluxeeRedemptions();
    }
  }

  List<RedeemedReward> get redeemedRewards => _redeemedRewards;
  bool get isLoading => _isLoading;
  int get totalPointsSpent => _totalPointsSpent;

  void update(AuthProvider authProvider) {
    if (authProvider.userProfile?.uid != _authProvider.userProfile?.uid) {
      _authProvider = authProvider;
      _subscribeToRedeemedRewards();
      _subscribeToPluxeeRedemptions();
    }
  }

  void _subscribeToRedeemedRewards() {
    _redeemedRewardsSubscription?.cancel();
    if (_authProvider.userProfile == null) {
      _redeemedRewards = [];
      _updateLoadingState();
      return;
    }

    _redeemedRewardsSubscription = _redeemedRewardService
        .getRedeemedRewards(_authProvider.userProfile!.uid)
        .listen((rewards) {
      _redeemedRewards = rewards;
      _updateLoadingState();
    }, onError: (error) {
      print('Error in redeemed rewards stream: $error');
      _updateLoadingState();
    });
  }

  void _subscribeToPluxeeRedemptions() {
    _pluxeeRedemptionSubscription?.cancel();
    if (_authProvider.userProfile == null) {
      _totalPointsSpent = 0;
      _updateLoadingState();
      return;
    }

    _pluxeeRedemptionSubscription = _firestore
        .collection('pluxeeRedemptionRequests')
        .where('userId', isEqualTo: _authProvider.userProfile!.uid)
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .listen((snapshot) {
      int totalPluxeePoints = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final pointsToRedeem = data['pointsToRedeem'] as int? ?? 0;
        totalPluxeePoints += pointsToRedeem;
      }
      
      // Calculate total points spent from both regular rewards and Pluxee redemptions
      final regularRewardsPoints = _redeemedRewards.fold(0, (sum, reward) => sum + reward.pointsSpent);
      _totalPointsSpent = regularRewardsPoints + totalPluxeePoints;
      
      _updateLoadingState();
    }, onError: (error) {
      print('Error in Pluxee redemption stream: $error');
      _updateLoadingState();
    });
  }

  void _updateLoadingState() {
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _redeemedRewardsSubscription?.cancel();
    _pluxeeRedemptionSubscription?.cancel();
    super.dispose();
  }
}
