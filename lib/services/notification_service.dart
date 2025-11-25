import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:novopharma/models/notification.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'notifications';

  Stream<List<NotificationItem>> getNotifications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection(_collection)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => NotificationItem.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> markAsRead(String userId, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection(_collection)
        .doc(notificationId)
        .update({'isRead': true});
  }
}
