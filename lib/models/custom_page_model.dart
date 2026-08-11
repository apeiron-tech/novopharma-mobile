import 'package:cloud_firestore/cloud_firestore.dart';

class CustomPageModel {
  final String id;
  final String title;
  final String description;
  final String status;
  final String? marqueId;
  final String? marqueName;
  final String? logoUrl;
  final List<String> imageUrls;
  final String? videoUrl;
  final bool isVideoFile;
  final String? attachmentUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CustomPageModel({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    this.marqueId,
    this.marqueName,
    this.logoUrl,
    required this.imageUrls,
    this.videoUrl,
    required this.isVideoFile,
    this.attachmentUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory CustomPageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return CustomPageModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      status: data['status'] ?? 'inactive',
      marqueId: data['marqueId'] as String?,
      marqueName: data['marqueName'] as String?,
      logoUrl: data['logoUrl'] as String?,
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      videoUrl: data['videoUrl'] as String?,
      isVideoFile: (data['isVideoFile'] as bool?) ?? false,
      attachmentUrl: data['attachmentUrl'] as String?,
      createdAt: parseTimestamp(data['createdAt']),
      updatedAt: parseTimestamp(data['updatedAt']),
    );
  }
}
