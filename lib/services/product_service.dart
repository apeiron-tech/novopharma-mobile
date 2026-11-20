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

  /// Looks a product up by its scanned barcode.
  ///
  /// The scanned value often isn't byte-identical to the stored SKU:
  /// - SKUs imported from Excel lose their leading zeros (numeric cells).
  /// - iOS reports UPC-A (12 digits) as EAN-13 with a leading '0', Android
  ///   reports it as 12 digits.
  /// - Some older products may have the SKU stored as a number.
  /// So we query every equivalent spelling of the barcode at once.
  Future<Product?> getProductBySku(String sku) async {
    final candidates = Product.skuLookupCandidates(sku);
    if (candidates.isEmpty) return null;
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('sku', whereIn: candidates)
          .limit(10)
          .get();
      if (querySnapshot.docs.isEmpty) return null;

      // Prefer an exact match, then an enabled product, then anything.
      final trimmed = sku.trim();
      final products = querySnapshot.docs
          .map((doc) => Product.fromFirestore(doc))
          .toList();
      return products.firstWhere(
        (p) => p.sku == trimmed,
        orElse: () => products.firstWhere(
          (p) => p.isEnabled,
          orElse: () => products.first,
        ),
      );
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
