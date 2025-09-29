import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:novopharma/models/redeemed_reward.dart';

class RedeemedRewardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> redeemReward({
    required String userId,
    required String userNameSnapshot,
    required String rewardId,
    required String rewardNameSnapshot,
    required int pointsSpent,
  }) async {
    final userRef = _firestore.collection('users').doc(userId);
    final rewardRef = _firestore.collection('rewards').doc(rewardId);
    final redeemedRewardRef = _firestore.collection('redeemedRewards').doc();

    await _firestore.runTransaction((transaction) async {
      // 1. Get the current state of the reward and user
      final rewardSnapshot = await transaction.get(rewardRef);
      final userSnapshot = await transaction.get(userRef);

      if (!rewardSnapshot.exists || !userSnapshot.exists) {
        throw Exception("User or Reward not found.");
      }

      final currentStock = rewardSnapshot.data()!['stock'] as int;
      final userPoints = userSnapshot.data()!['points'] as int;

      // 2. Validate the transaction
      if (currentStock <= 0) {
        throw Exception("Reward is out of stock.");
      }
      if (userPoints < pointsSpent) {
        throw Exception("Insufficient points.");
      }

      // 3. Perform the atomic writes
      transaction.set(redeemedRewardRef, {
        'userId': userId,
        'userNameSnapshot': userNameSnapshot,
        'rewardId': rewardId,
        'rewardNameSnapshot': rewardNameSnapshot,
        'pointsSpent': pointsSpent,
        'createdAt': FieldValue.serverTimestamp(),
        'redeemedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(userRef, {'points': FieldValue.increment(-pointsSpent)});
      transaction.update(rewardRef, {'stock': FieldValue.increment(-1)});
    });
  }

  Stream<List<RedeemedReward>> getRedeemedRewards(String userId) {
    try {
      print('Setting up redeemed rewards stream for userId: $userId');
      return _firestore
          .collection('redeemedRewards')
          .where('userId', isEqualTo: userId)
          .orderBy('redeemedAt', descending: true)
          .snapshots()
          .map((querySnapshot) {
        print('Received ${querySnapshot.docs.length} redeemed rewards update.');
        return querySnapshot.docs
            .map((doc) => RedeemedReward.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      print('Error setting up redeemed rewards stream: $e');
      return Stream.value([]);
    }
  }
}

