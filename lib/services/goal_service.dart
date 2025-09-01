import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:novopharma/models/goal.dart';
import 'package:novopharma/models/product.dart';

class GoalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'goals';

  Future<List<Goal>> getActiveGoals() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();
      final List<Goal> goals =
          querySnapshot.docs.map((doc) => Goal.fromFirestore(doc)).toList();
      return goals;
    } catch (e) {
      print('Error fetching goals: $e');
      return [];
    }
  }

  Future<List<Goal>> findMatchingGoals(Product product) async {
    try {
      final now = DateTime.now();
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .where('startDate', isLessThanOrEqualTo: now)
          .where('endDate', isGreaterThanOrEqualTo: now)
          .get();

      final List<Goal> goals = querySnapshot.docs
          .map((doc) => Goal.fromFirestore(doc))
          .where((goal) {
            final criteria = goal.criteria;
            if (criteria == null) return false;

            final matchesProduct = criteria.products?.contains(product.id) ?? false;
            final matchesBrand = criteria.brands?.contains(product.marque) ?? false;
            final matchesCategory = criteria.categories?.contains(product.category) ?? false;

            bool productOk = criteria.products?.isNotEmpty == true ? matchesProduct : false;
            bool brandOk = criteria.brands?.isNotEmpty == true ? matchesBrand : false;
            bool categoryOk = criteria.categories?.isNotEmpty == true ? matchesCategory : false;

            return productOk || brandOk || categoryOk;
          })
          .toList();
          
      return goals;
    } catch (e) {
      print('Error finding matching goals: $e');
      return [];
    }
  }
}
