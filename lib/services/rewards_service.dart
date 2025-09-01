import 'dart:developer';
import 'package:novopharma/models/reward.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RewardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'rewards';

  Future<List<Reward>> getRewards() async {
    try {
      final querySnapshot = await _firestore.collection(_collection).get();
      final List<Reward> rewards = querySnapshot.docs
          .map((doc) => Reward.fromFirestore(doc))
          .toList();
      log('Fetched rewards: ${rewards.length}');
      return rewards;
    } catch (e) {
      log('Error fetching rewards: $e');
      return [];
    }
  }
}
