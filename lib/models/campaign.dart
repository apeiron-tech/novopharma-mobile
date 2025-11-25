import 'package:cloud_firestore/cloud_firestore.dart';

class Campaign {
  final String id;
  final String title;
  final String description;
  final String coverImageUrl;
  final String? videoUrl;
  final CampaignProductCriteria productCriteria;
  final List<String> tradeOfferProductIds;
  final String linkedGoalId;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Campaign({
    required this.id,
    required this.title,
    required this.description,
    required this.coverImageUrl,
    this.videoUrl,
    required this.productCriteria,
    required this.tradeOfferProductIds,
    required this.linkedGoalId,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Campaign.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Campaign(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      coverImageUrl: data['coverImageUrl'] ?? '',
      videoUrl: data['videoUrl'],
      productCriteria: CampaignProductCriteria.fromMap(
        data['productCriteria'] ?? {},
      ),
      tradeOfferProductIds: List<String>.from(
        data['tradeOfferProductIds'] ?? [],
      ),
      linkedGoalId: data['linkedGoalId'] ?? '',
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class CampaignProductCriteria {
  final List<String> categories;
  final List<String> marques;
  final List<String> products;

  CampaignProductCriteria({
    required this.categories,
    required this.marques,
    required this.products,
  });

  factory CampaignProductCriteria.fromMap(Map<String, dynamic> data) {
    return CampaignProductCriteria(
      categories: List<String>.from(data['categories'] ?? []),
      marques: List<String>.from(data['marques'] ?? []),
      products: List<String>.from(data['products'] ?? []),
    );
  }
}
