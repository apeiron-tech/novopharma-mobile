import 'package:novopharma/models/gift.dart';
import 'package:novopharma/models/gift_assignment.dart';
import 'package:novopharma/models/product.dart';
import 'package:novopharma/models/basket_item.dart';

class GiftThresholdEvaluation {
  final Gift gift;
  final GiftAssignment assignment;
  final int matchingQuantity;
  final double matchingAmount;
  final bool isThresholdMet;
  final int neededQuantity;
  final double neededAmount;
  final int targetQuantity;
  final double targetAmount;

  GiftThresholdEvaluation({
    required this.gift,
    required this.assignment,
    required this.matchingQuantity,
    required this.matchingAmount,
    required this.isThresholdMet,
    required this.neededQuantity,
    required this.neededAmount,
    required this.targetQuantity,
    required this.targetAmount,
  });
}

class GiftEligibilityService {
  /// Checks whether a single product matches the targeting criteria of a Gift.
  static bool productMatchesGift(Gift gift, {
    required String productId,
    required String productCategory,
    required String productMarque,
  }) {
    if (gift.status != 'active') return false;

    if (gift.listProducts.isNotEmpty && !gift.listProducts.contains(productId)) {
      return false;
    }
    if (gift.productCategory.isNotEmpty &&
        !gift.productCategory.contains(productCategory)) {
      return false;
    }
    if (gift.productMarque.isNotEmpty &&
        !gift.productMarque.contains(productMarque)) {
      return false;
    }
    return true;
  }

  /// Evaluates a list of gift assignments against the current basket items.
  static List<GiftThresholdEvaluation> evaluateBasket({
    required List<GiftAssignment> assignments,
    required Map<String, Gift> giftsMap,
    required List<BasketItem> items,
  }) {
    final List<GiftThresholdEvaluation> results = [];

    for (final assignment in assignments) {
      final gift = giftsMap[assignment.giftId];
      if (gift == null || gift.status != 'active') continue;

      int matchingQty = 0;
      double matchingAmt = 0.0;

      for (final item in items) {
        if (productMatchesGift(
          gift,
          productId: item.productId,
          productCategory: item.category ?? '',
          productMarque: item.marque ?? '',
        )) {
          matchingQty += item.quantity;
          matchingAmt += item.lineTotal;
        }
      }

      bool isMet = false;
      int neededQty = 0;
      double neededAmt = 0.0;
      int targetQty = 0;
      double targetAmt = 0.0;

      if (gift.thresholdType == 'products') {
        targetQty = gift.minProductsCount ?? 1;
        isMet = matchingQty >= targetQty && matchingQty > 0;
        neededQty = matchingQty < targetQty ? targetQty - matchingQty : 0;
      } else if (gift.thresholdType == 'amount') {
        targetAmt = gift.minPurchaseAmount ?? 0.0;
        isMet = matchingAmt >= targetAmt && matchingAmt > 0;
        neededAmt = matchingAmt < targetAmt ? targetAmt - matchingAmt : 0.0;
      } else {
        // Default threshold
        targetQty = gift.minProductsCount ?? 1;
        isMet = matchingQty >= targetQty && matchingQty > 0;
        neededQty = matchingQty < targetQty ? targetQty - matchingQty : 0;
      }

      results.add(GiftThresholdEvaluation(
        gift: gift,
        assignment: assignment,
        matchingQuantity: matchingQty,
        matchingAmount: matchingAmt,
        isThresholdMet: isMet,
        neededQuantity: neededQty,
        neededAmount: neededAmt,
        targetQuantity: targetQty,
        targetAmount: targetAmt,
      ));
    }

    return results;
  }

  /// Evaluates gift eligibility for direct sale from productsToSell map
  static List<GiftThresholdEvaluation> evaluateDirectSale({
    required List<GiftAssignment> assignments,
    required Map<String, Gift> giftsMap,
    required Map<Product, int> productsToSell,
  }) {
    final items = productsToSell.entries.map((e) {
      final p = e.key;
      final q = e.value;
      return BasketItem(
        productId: p.id,
        name: p.name,
        sku: p.sku,
        marque: p.marque,
        category: p.category,
        unitPrice: p.price,
        quantity: q,
        lineTotal: p.price * q,
        pointsEarned: 0,
      );
    }).toList();

    return evaluateBasket(
      assignments: assignments,
      giftsMap: giftsMap,
      items: items,
    );
  }
}

