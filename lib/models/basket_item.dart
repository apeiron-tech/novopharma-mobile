class BasketItem {
  final String productId;
  final String name;
  final String? sku;
  final String? marque;
  final String? category;
  final String? imageUrl;
  final double unitPrice;
  int quantity;
  double lineTotal;
  double pointsEarned;
  String? saleId;

  BasketItem({
    required this.productId,
    required this.name,
    this.sku,
    this.marque,
    this.category,
    this.imageUrl,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
    required this.pointsEarned,
    this.saleId,
  });

  factory BasketItem.fromMap(Map<String, dynamic> map) {
    return BasketItem(
      productId: map['productId'] ?? '',
      name: map['name'] ?? '',
      sku: map['sku'],
      marque: map['marque'],
      category: map['category'],
      imageUrl: map['imageUrl'],
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      lineTotal: (map['lineTotal'] as num?)?.toDouble() ?? 0.0,
      pointsEarned: (map['pointsEarned'] as num?)?.toDouble() ?? 0.0,
      saleId: map['saleId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      if (sku != null) 'sku': sku,
      if (marque != null) 'marque': marque,
      if (category != null) 'category': category,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'unitPrice': unitPrice,
      'quantity': quantity,
      'lineTotal': lineTotal,
      'pointsEarned': pointsEarned,
      if (saleId != null) 'saleId': saleId,
    };
  }

  BasketItem copyWith({
    int? quantity,
    double? lineTotal,
    double? pointsEarned,
    String? saleId,
  }) {
    return BasketItem(
      productId: productId,
      name: name,
      sku: sku,
      marque: marque,
      category: category,
      imageUrl: imageUrl,
      unitPrice: unitPrice,
      quantity: quantity ?? this.quantity,
      lineTotal: lineTotal ?? this.lineTotal,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      saleId: saleId ?? this.saleId,
    );
  }
}

