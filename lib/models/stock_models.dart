class StockExpiration {
  final String expirationDate; // YYYY-MM-DD
  final int quantity;

  StockExpiration({
    required this.expirationDate,
    required this.quantity,
  });

  Map<String, dynamic> toJson() {
    return {
      'expirationDate': expirationDate,
      'quantity': quantity,
    };
  }

  factory StockExpiration.fromJson(Map<String, dynamic> json) {
    return StockExpiration(
      expirationDate: json['expirationDate'] ?? '',
      quantity: json['quantity'] ?? 0,
    );
  }
}

class ProductStockItem {
  final String productId;
  final String productName;
  int? totalQuantity;
  List<StockExpiration> expirations;
  bool respectsPrice;
  double? sellingPrice;
  double? priceDifference;
  double? recommendedPrice;
  bool isPriceOnly;

  ProductStockItem({
    required this.productId,
    required this.productName,
    this.totalQuantity,
    required this.expirations,
    this.respectsPrice = true,
    this.sellingPrice,
    this.priceDifference,
    this.recommendedPrice,
    this.isPriceOnly = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'totalQuantity': totalQuantity,
      'expirations': expirations.map((e) => e.toJson()).toList(),
      'respectsPrice': respectsPrice,
      'sellingPrice': sellingPrice,
      'priceDifference': priceDifference,
      'recommendedPrice': recommendedPrice,
      'isPriceOnly': isPriceOnly,
    };
  }

  factory ProductStockItem.fromJson(Map<String, dynamic> json) {
    var expList = json['expirations'] as List? ?? [];
    final totalQty = json['totalQuantity'] != null ? (json['totalQuantity'] as num).toInt() : null;
    final isPriceOnly = json['isPriceOnly'] ?? (totalQty == null);
    return ProductStockItem(
      productId: json['productId'] ?? '',
      productName: json['productName'] ?? '',
      totalQuantity: totalQty,
      expirations: expList.map((e) => StockExpiration.fromJson(e)).toList(),
      respectsPrice: json['respectsPrice'] ?? true,
      sellingPrice: json['sellingPrice'] != null ? (json['sellingPrice'] as num).toDouble() : null,
      priceDifference: json['priceDifference'] != null ? (json['priceDifference'] as num).toDouble() : null,
      recommendedPrice: json['recommendedPrice'] != null ? (json['recommendedPrice'] as num).toDouble() : null,
      isPriceOnly: isPriceOnly,
    );
  }

  // Recalculates totalQuantity based on expirations
  void syncTotalQuantity() {
    if (expirations.isNotEmpty) {
      totalQuantity = expirations.fold<int>(0, (acc, exp) => acc + exp.quantity);
      isPriceOnly = false;
    }
  }
}

