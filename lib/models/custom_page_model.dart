import 'package:cloud_firestore/cloud_firestore.dart';

class CustomPageProductItem {
  final String id;
  final String name;
  final String marque;
  final String category;
  final double price;
  final double points;
  final double pointsPharmacie;
  final double pointsParaPharmacie;
  final String imageUrl;
  final String sku;

  CustomPageProductItem({
    required this.id,
    required this.name,
    this.marque = '',
    this.category = '',
    this.price = 0.0,
    this.points = 0.0,
    this.pointsPharmacie = 0.0,
    this.pointsParaPharmacie = 0.0,
    this.imageUrl = '',
    this.sku = '',
  });

  factory CustomPageProductItem.fromMap(Map<String, dynamic> data) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return CustomPageProductItem(
      id: (data['id'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      marque: (data['marque'] ?? '').toString(),
      category: (data['category'] ?? '').toString(),
      price: parseDouble(data['price']),
      points: parseDouble(data['points']),
      pointsPharmacie: parseDouble(data['pointsPharmacie']),
      pointsParaPharmacie: parseDouble(data['pointsParaPharmacie']),
      imageUrl: (data['imageUrl'] ?? '').toString().trim(),
      sku: (data['sku'] ?? '').toString(),
    );
  }

  double getDisplayPoints(String? pharmacyCategory) {
    if (pharmacyCategory == 'Para-Pharmacie' && pointsParaPharmacie > 0) {
      return pointsParaPharmacie;
    }
    if (pharmacyCategory == 'Pharmacie' && pointsPharmacie > 0) {
      return pointsPharmacie;
    }
    return points;
  }
}

class CustomPageModel {
  final String id;
  final String title;
  final String description;
  final String status;
  final String? marqueId;
  final String? marqueName;
  final List<String> marqueIds;
  final List<String> marqueNames;
  final String? logoUrl;
  final List<String> imageUrls;
  final String? videoUrl;
  final bool isVideoFile;
  final String? attachmentUrl;
  final List<CustomPageProductItem> products;
  final List<String> productIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CustomPageModel({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    this.marqueId,
    this.marqueName,
    this.marqueIds = const [],
    this.marqueNames = const [],
    this.logoUrl,
    required this.imageUrls,
    this.videoUrl,
    required this.isVideoFile,
    this.attachmentUrl,
    this.products = const [],
    this.productIds = const [],
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

    final rawProducts = data['products'];
    List<CustomPageProductItem> parsedProducts = [];
    if (rawProducts is List) {
      for (var item in rawProducts) {
        if (item is Map) {
          parsedProducts.add(
            CustomPageProductItem.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final rawMarqueIds = data['marqueIds'];
    List<String> parsedMarqueIds = [];
    if (rawMarqueIds is List) {
      parsedMarqueIds = rawMarqueIds.map((e) => e.toString()).toList();
    } else if (data['marqueId'] != null && data['marqueId'].toString().isNotEmpty) {
      parsedMarqueIds = [data['marqueId'].toString()];
    }

    final rawMarqueNames = data['marqueNames'];
    List<String> parsedMarqueNames = [];
    if (rawMarqueNames is List) {
      parsedMarqueNames = rawMarqueNames.map((e) => e.toString()).toList();
    } else if (data['marqueName'] != null && data['marqueName'].toString().isNotEmpty) {
      parsedMarqueNames = [data['marqueName'].toString()];
    }

    return CustomPageModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      status: data['status'] ?? 'inactive',
      marqueId: data['marqueId'] as String?,
      marqueName: data['marqueName'] as String?,
      marqueIds: parsedMarqueIds,
      marqueNames: parsedMarqueNames,
      logoUrl: data['logoUrl'] as String?,
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      videoUrl: data['videoUrl'] as String?,
      isVideoFile: (data['isVideoFile'] as bool?) ?? false,
      attachmentUrl: data['attachmentUrl'] as String?,
      products: parsedProducts,
      productIds: List<String>.from(data['productIds'] ?? []),
      createdAt: parseTimestamp(data['createdAt']),
      updatedAt: parseTimestamp(data['updatedAt']),
    );
  }
}

