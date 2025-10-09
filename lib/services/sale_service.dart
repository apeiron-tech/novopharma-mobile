import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:novopharma/models/sale.dart';

class SaleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'sales';

  Future<void> createSale(Sale sale) async {
    final userRef = _firestore.collection('users').doc(sale.userId);
    final saleRef = _firestore.collection(_collection).doc();
    final productRef = _firestore.collection('products').doc(sale.productId);

    final saleData = sale.toFirestore();
    log('Attempting to create sale with data: $saleData');

    await _firestore.runTransaction((transaction) async {
      // 1. Read the product document
      final productSnapshot = await transaction.get(productRef);

      if (!productSnapshot.exists) {
        throw Exception("Product does not exist!");
      }

      final currentStock = productSnapshot.data()!['stock'] as int;

      // 2. Verify stock
      if (currentStock < sale.quantity) {
        throw Exception("Insufficient stock for ${productSnapshot.data()!['name']}. Available: $currentStock, Requested: ${sale.quantity}");
      }

      // 3. Create the new sale document
      transaction.set(saleRef, saleData);
      
      // 4. Atomically update the user's points
      transaction.update(userRef, {
        'points': FieldValue.increment(sale.pointsEarned),
      });

      // 5. Atomically decrement the product's stock
      transaction.update(productRef, {
        'stock': FieldValue.increment(-sale.quantity),
      });
    }).catchError((error) {
      log('Error in createSale transaction: $error');
      // Rethrow the error to be caught by the provider
      throw error;
    });
  }

  Future<void> updateSale(Sale oldSale, Sale newSale) async {
    final userRef = _firestore.collection('users').doc(newSale.userId);
    final saleRef = _firestore.collection(_collection).doc(newSale.id);
    final productRef = _firestore.collection('products').doc(newSale.productId);

    log('Attempting to update sale ${newSale.id}');

    await _firestore.runTransaction((transaction) async {
      final productSnapshot = await transaction.get(productRef);
      if (!productSnapshot.exists) throw Exception("Product does not exist!");

      final currentStock = productSnapshot.data()!['stock'] as int;
      final quantityDifference = newSale.quantity - oldSale.quantity;

      if (currentStock < quantityDifference) {
        throw Exception("Insufficient stock for update. Available: $currentStock, Requested change: $quantityDifference");
      }

      transaction.update(saleRef, newSale.toFirestore());

      final pointsDifference = newSale.pointsEarned - oldSale.pointsEarned;
      transaction.update(userRef, {'points': FieldValue.increment(pointsDifference)});
      
      transaction.update(productRef, {'stock': FieldValue.increment(-quantityDifference)});
    }).catchError((error) {
      log('Error in updateSale transaction: $error');
      throw error;
    });
  }

  Future<void> deleteSale(Sale sale) async {
    final userRef = _firestore.collection('users').doc(sale.userId);
    final saleRef = _firestore.collection(_collection).doc(sale.id);
    final productRef = _firestore.collection('products').doc(sale.productId);

    log('Attempting to delete sale ${sale.id}');

    await _firestore.runTransaction((transaction) async {
      transaction.delete(saleRef);
      transaction.update(userRef, {'points': FieldValue.increment(-sale.pointsEarned)});
      transaction.update(productRef, {'stock': FieldValue.increment(sale.quantity)});
    }).catchError((error) {
      log('Error in deleteSale transaction: $error');
      throw error;
    });
  }

  Future<List<Sale>> getSalesHistory(String userId, {DateTime? startDate, DateTime? endDate}) async {
    try {
      Query query = _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('saleDate', descending: true);

      if (startDate != null) {
        query = query.where('saleDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        // To include the whole end day, we set the time to the end of the day.
        final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        query = query.where('saleDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
      }

      final querySnapshot = await query.get();
      final List<Sale> sales =
          querySnapshot.docs.map((doc) => Sale.fromFirestore(doc)).toList();
      return sales;
    } catch (e) {
      print('Error fetching sales history: $e');
      return [];
    }
  }
}
