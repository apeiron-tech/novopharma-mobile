import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationItem {
  final String id;
  final String title;
  final String description;
  final DateTime timestamp;
  final bool isRead;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    this.isRead = false,
  });

  factory NotificationItem.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return NotificationItem(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
    );
  }

  NotificationItem copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}
