import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:novopharma/models/product.dart';

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'products';

  Future<List<Product>> getProducts() async {
    try {
      final querySnapshot = await _firestore.collection(_collection).get();
      final List<Product> products = querySnapshot.docs
          .map((doc) => Product.fromFirestore(doc))
          .toList();
      return products;
    } catch (e) {
      print('Error fetching products: $e');
      return [];
    }
  }

  Future<Product?> getProductBySku(String sku) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('sku', isEqualTo: sku)
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        return Product.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      print('Error fetching product by sku: $e');
      return null;
    }
  }

  Future<Product?> getProductById(String id) async {
    try {
      final docSnapshot = await _firestore
          .collection(_collection)
          .doc(id)
          .get();
      if (docSnapshot.exists) {
        return Product.fromFirestore(docSnapshot);
      }
      return null;
    } catch (e) {
      print('Error fetching product by id: $e');
      return null;
    }
  }

  Future<List<Product>> getProductsByIds(List<String> ids) async {
    if (ids.isEmpty) {
      return [];
    }
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where(FieldPath.documentId, whereIn: ids)
          .get();
      final List<Product> products = querySnapshot.docs
          .map((doc) => Product.fromFirestore(doc))
          .toList();
      return products;
    } catch (e) {
      print('Error fetching products by ids: $e');
      return [];
    }
  }
}
