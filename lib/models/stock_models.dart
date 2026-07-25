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
  int totalQuantity;
  List<StockExpiration> expirations;
  bool respectsPrice;
  double? sellingPrice;
  double? priceDifference;
  double? recommendedPrice;

  ProductStockItem({
    required this.productId,
    required this.productName,
    this.totalQuantity = 0,
    required this.expirations,
    this.respectsPrice = true,
    this.sellingPrice,
    this.priceDifference,
    this.recommendedPrice,
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
    };
  }

  factory ProductStockItem.fromJson(Map<String, dynamic> json) {
    var expList = json['expirations'] as List? ?? [];
    return ProductStockItem(
      productId: json['productId'] ?? '',
      productName: json['productName'] ?? '',
      totalQuantity: json['totalQuantity'] ?? 0,
      expirations: expList.map((e) => StockExpiration.fromJson(e)).toList(),
      respectsPrice: json['respectsPrice'] ?? true,
      sellingPrice: json['sellingPrice'] != null ? (json['sellingPrice'] as num).toDouble() : null,
      priceDifference: json['priceDifference'] != null ? (json['priceDifference'] as num).toDouble() : null,
      recommendedPrice: json['recommendedPrice'] != null ? (json['recommendedPrice'] as num).toDouble() : null,
    );
  }

  // Recalculates totalQuantity based on expirations
  void syncTotalQuantity() {
    if (expirations.isNotEmpty) {
      totalQuantity = expirations.fold(0, (sum, exp) => sum + exp.quantity);
    }
  }
}
