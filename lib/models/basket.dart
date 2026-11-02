import 'package:cloud_firestore/cloud_firestore.dart';
import 'basket_item.dart';

class Basket {
  final String id;
  final String userId;
  final String? userNameSnapshot;
  final dynamic userDisplayIdSnapshot;
  final String? userRole;
  final String? visitId;
  final String pharmacyId;
  final String? pharmacyNameSnapshot;
  final String? pointOfSaleSnapshot;
  final String? pharmacyClientCategorySnapshot;
  final String? pharmacyZoneSnapshot;
  final int? basketNumber;
  final String status; // 'open' | 'closed' | 'cancelled'
  final DateTime openedAt;
  final DateTime? closedAt;
  final String? closedBy;
  final String? closedByRole;
  final String? animationDate;
  final List<BasketItem> items;
  final double totalAmount;
  final int itemsCount;
  final int distinctProductsCount;
  final double totalPoints;
  final List<String> brands;
  final Map<String, dynamic>? brandTotals;
  final List<String> giftOperationIds;
  final List<Map<String, dynamic>> giftsGiven;
  final bool hasGift;
  final List<String> goalIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Basket({
    required this.id,
    required this.userId,
    this.userNameSnapshot,
    this.userDisplayIdSnapshot,
    this.userRole,
    this.visitId,
    required this.pharmacyId,
    this.pharmacyNameSnapshot,
    this.pointOfSaleSnapshot,
    this.pharmacyClientCategorySnapshot,
    this.pharmacyZoneSnapshot,
    this.basketNumber,
    required this.status,
    required this.openedAt,
    this.closedAt,
    this.closedBy,
    this.closedByRole,
    this.animationDate,
    required this.items,
    required this.totalAmount,
    required this.itemsCount,
    required this.distinctProductsCount,
    required this.totalPoints,
    required this.brands,
    this.brandTotals,
    this.giftOperationIds = const [],
    this.giftsGiven = const [],
    this.hasGift = false,
    this.goalIds = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory Basket.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawItems = data['items'] as List<dynamic>? ?? [];
    final itemsList = rawItems
        .map((item) => BasketItem.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();

    return Basket(
      id: doc.id,
      userId: data['userId'] ?? '',
      userNameSnapshot: data['userNameSnapshot'],
      userDisplayIdSnapshot: data['userDisplayIdSnapshot'],
      userRole: data['userRole'],
      visitId: data['visitId'],
      pharmacyId: data['pharmacyId'] ?? '',
      pharmacyNameSnapshot: data['pharmacyNameSnapshot'],
      pointOfSaleSnapshot: data['pointOfSaleSnapshot'],
      pharmacyClientCategorySnapshot: data['pharmacyClientCategorySnapshot'],
      pharmacyZoneSnapshot: data['pharmacyZoneSnapshot'],
      basketNumber: data['basketNumber'] as int?,
      status: data['status'] ?? 'open',
      openedAt: (data['openedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      closedAt: (data['closedAt'] as Timestamp?)?.toDate(),
      closedBy: data['closedBy'],
      closedByRole: data['closedByRole'],
      animationDate: data['animationDate'],
      items: itemsList,
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      itemsCount: (data['itemsCount'] as num?)?.toInt() ?? 0,
      distinctProductsCount: (data['distinctProductsCount'] as num?)?.toInt() ?? itemsList.length,
      totalPoints: (data['totalPoints'] as num?)?.toDouble() ?? 0.0,
      brands: List<String>.from(data['brands'] ?? []),
      brandTotals: data['brandTotals'] as Map<String, dynamic>?,
      giftOperationIds: List<String>.from(data['giftOperationIds'] ?? []),
      giftsGiven: (data['giftsGiven'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      hasGift: data['hasGift'] as bool? ?? false,
      goalIds: List<String>.from(data['goalIds'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      if (userNameSnapshot != null) 'userNameSnapshot': userNameSnapshot,
      if (userDisplayIdSnapshot != null) 'userDisplayIdSnapshot': userDisplayIdSnapshot,
      if (userRole != null) 'userRole': userRole,
      if (visitId != null) 'visitId': visitId,
      'pharmacyId': pharmacyId,
      if (pharmacyNameSnapshot != null) 'pharmacyNameSnapshot': pharmacyNameSnapshot,
      if (pointOfSaleSnapshot != null) 'pointOfSaleSnapshot': pointOfSaleSnapshot,
      if (pharmacyClientCategorySnapshot != null)
        'pharmacyClientCategorySnapshot': pharmacyClientCategorySnapshot,
      if (pharmacyZoneSnapshot != null) 'pharmacyZoneSnapshot': pharmacyZoneSnapshot,
      if (basketNumber != null) 'basketNumber': basketNumber,
      'status': status,
      'openedAt': Timestamp.fromDate(openedAt),
      if (closedAt != null) 'closedAt': Timestamp.fromDate(closedAt!),
      if (closedBy != null) 'closedBy': closedBy,
      if (closedByRole != null) 'closedByRole': closedByRole,
      if (animationDate != null) 'animationDate': animationDate,
      'items': items.map((i) => i.toMap()).toList(),
      'totalAmount': totalAmount,
      'itemsCount': itemsCount,
      'distinctProductsCount': distinctProductsCount,
      'totalPoints': totalPoints,
      'brands': brands,
      if (brandTotals != null) 'brandTotals': brandTotals,
      'giftOperationIds': giftOperationIds,
      'giftsGiven': giftsGiven,
      'hasGift': hasGift,
      'goalIds': goalIds,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

