import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:novopharma/models/basket.dart';
import 'package:novopharma/models/basket_item.dart';
import 'package:novopharma/models/sale.dart';

class BasketService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
  final String _collection = 'baskets';

  /// Get the current open basket for a user, if any.
  Future<Basket?> getOpenBasket(String userId) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'open')
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        return Basket.fromFirestore(snap.docs.first);
      }
      return null;
    } catch (e) {
      log('[BasketService] Error getting open basket: $e');
      return null;
    }
  }

  /// Reactive stream for the user's active open basket.
  Stream<Basket?> streamOpenBasket(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'open')
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isNotEmpty) {
        return Basket.fromFirestore(snap.docs.first);
      }
      return null;
    });
  }

  /// Create a new open basket.
  Future<Basket> createOpenBasket({
    required String userId,
    String? userName,
    dynamic userDisplayId,
    String? userRole,
    String? visitId,
    required String pharmacyId,
    String? pharmacyName,
    String? pointOfSale,
    String? pharmacyClientCategory,
    String? pharmacyZone,
  }) async {
    int nextNumber = 1;
    if (visitId != null && visitId.isNotEmpty) {
      try {
        final visitBaskets = await _firestore
            .collection(_collection)
            .where('visitId', isEqualTo: visitId)
            .get();
        nextNumber = visitBaskets.docs.length + 1;
      } catch (e) {
        log('[BasketService] Error counting visit baskets: $e');
      }
    }

    final docRef = _firestore.collection(_collection).doc();
    final newBasket = Basket(
      id: docRef.id,
      userId: userId,
      userNameSnapshot: userName,
      userDisplayIdSnapshot: userDisplayId,
      userRole: userRole ?? 'Dermo-conseiller',
      visitId: visitId,
      pharmacyId: pharmacyId,
      pharmacyNameSnapshot: pharmacyName,
      pointOfSaleSnapshot: pointOfSale,
      pharmacyClientCategorySnapshot: pharmacyClientCategory ?? 'Dermo-conseiller',
      pharmacyZoneSnapshot: pharmacyZone,
      basketNumber: nextNumber,
      status: 'open',
      openedAt: DateTime.now(),
      items: [],
      totalAmount: 0.0,
      itemsCount: 0,
      distinctProductsCount: 0,
      totalPoints: 0.0,
      brands: [],
      brandTotals: {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await docRef.set(newBasket.toFirestore());
    return newBasket;
  }

  /// Updates items in an open basket and recalculates totals.
  Future<void> updateBasketItems(String basketId, List<BasketItem> items) async {
    double totalAmount = 0.0;
    int itemsCount = 0;
    double totalPoints = 0.0;
    final Set<String> brands = {};
    final Map<String, dynamic> brandTotals = {};

    for (final item in items) {
      final lineTotal = item.unitPrice * item.quantity;
      item.lineTotal = double.parse(lineTotal.toStringAsFixed(3));
      totalAmount += item.lineTotal;
      itemsCount += item.quantity;
      totalPoints += item.pointsEarned;

      final brand = (item.marque ?? 'Sans marque').trim();
      brands.add(brand);

      if (!brandTotals.containsKey(brand)) {
        brandTotals[brand] = {'amount': 0.0, 'qty': 0};
      }
      brandTotals[brand]['amount'] = (brandTotals[brand]['amount'] as num).toDouble() + item.lineTotal;
      brandTotals[brand]['qty'] = (brandTotals[brand]['qty'] as num).toInt() + item.quantity;
    }

    await _firestore.collection(_collection).doc(basketId).update({
      'items': items.map((i) => i.toMap()).toList(),
      'totalAmount': double.parse(totalAmount.toStringAsFixed(3)),
      'itemsCount': itemsCount,
      'distinctProductsCount': items.length,
      'totalPoints': double.parse(totalPoints.toStringAsFixed(2)),
      'brands': brands.toList(),
      'brandTotals': brandTotals,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cancel an open basket.
  Future<void> cancelBasket(String basketId, {String? reason}) async {
    await _firestore.collection(_collection).doc(basketId).update({
      'status': 'cancelled',
      'cancellationReason': reason ?? 'Annulé par la dermo-conseillère',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Clôturer le panier via Callable Cloud Function.
  Future<Map<String, dynamic>> closeBasket({
    required String basketId,
    String? selectedGiftId,
    String? selectedAssignmentId,
    int giftQuantity = 1,
    String? clientNom,
    String? clientPrenom,
    String? clientPhone,
  }) async {
    final callable = _functions.httpsCallable('closeBasket');
    final result = await callable.call({
      'basketId': basketId,
      'selectedGiftId': selectedGiftId,
      'selectedAssignmentId': selectedAssignmentId,
      'giftQuantity': giftQuantity,
      'clientNom': clientNom ?? '',
      'clientPrenom': clientPrenom ?? '',
      'clientPhone': clientPhone ?? '',
    });

    return Map<String, dynamic>.from(result.data as Map);
  }

  /// Get closed baskets for a visit.
  Future<List<Basket>> getClosedBasketsForVisit(String visitId) async {
    try {
      final snap = await _firestore
          .collection(_collection)
          .where('visitId', isEqualTo: visitId)
          .where('status', isEqualTo: 'closed')
          .orderBy('closedAt', descending: true)
          .get();

      return snap.docs.map((doc) => Basket.fromFirestore(doc)).toList();
    } catch (e) {
      log('[BasketService] Error getting visit closed baskets: $e');
      return [];
    }
  }

  /// Get a single basket by its ID.
  Future<Basket?> getBasketById(String basketId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(basketId).get();
      if (doc.exists) {
        return Basket.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      log('[BasketService] Error getting basket by ID: $e');
      return null;
    }
  }

  /// Get all sales assigned to a basket.
  Future<List<Sale>> getSalesForBasket(String basketId) async {
    try {
      final snap = await _firestore
          .collection('sales')
          .where('basketId', isEqualTo: basketId)
          .get();
      return snap.docs
          .map((doc) => Sale.fromFirestore(doc))
          .where((s) => s.status != 'DELETED')
          .toList();
    } catch (e) {
      log('[BasketService] Error getting sales for basket: $e');
      return [];
    }
  }
}

