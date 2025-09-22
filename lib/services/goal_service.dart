import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:novopharma/models/goal.dart';
import 'package:novopharma/models/pharmacy.dart';
import 'package:novopharma/models/product.dart';
import 'package:novopharma/models/user_goal_progress.dart';
import 'package:novopharma/models/user_model.dart';

class GoalService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<Goal>> getUserGoals() async {
    final user = _auth.currentUser;
    if (user == null) {
      log('Error: No authenticated user found.');
      return [];
    }

    try {
      final goalsSnapshot = await _db
          .collection('goals')
          .where('isActive', isEqualTo: true)
          .get();

      if (goalsSnapshot.docs.isEmpty) {
        log('No active goals found in the database.');
        return [];
      }

      final progressSnapshot = await _db
          .collection('users')
          .doc(user.uid)
          .collection('userGoalProgress')
          .get();

      final Map<String, UserGoalProgress> userProgress = {
        for (var doc in progressSnapshot.docs)
          doc.id: UserGoalProgress.fromMap(doc.id, doc.data()),
      };

      final List<Goal> goals = goalsSnapshot.docs.map((doc) {
        final goalData = doc.data();
        goalData['id'] = doc.id;
        final progress = userProgress[doc.id];
        goalData['userProgress'] =
            progress?.toMap() ?? {'progressValue': 0, 'status': 'in-progress'};
        return Goal.fromMap(goalData);
      }).toList();

      return goals;
    } catch (e, s) {
      log('Error fetching user goals directly from Firestore', error: e, stackTrace: s);
      return [];
    }
  }

  List<Goal> findMatchingGoals(Product product, List<Goal> allGoals) {
    return allGoals.where((goal) {
      final criteria = goal.criteria;
      final matchesProduct = criteria.products.contains(product.id);
      final matchesBrand = criteria.brands.contains(product.marque);
      final matchesCategory = criteria.categories.contains(product.category);
      bool productOk = criteria.products.isNotEmpty ? matchesProduct : false;
      bool brandOk = criteria.brands.isNotEmpty ? matchesBrand : false;
      bool categoryOk = criteria.categories.isNotEmpty ? matchesCategory : false;
      return productOk || brandOk || categoryOk;
    }).toList();
  }

  Future<bool> isUserEligibleForGoal(
      Goal goal, Product product, UserModel user, Pharmacy pharmacy) async {
    final criteria = goal.criteria;

    if (criteria.categories.isNotEmpty && !criteria.categories.contains(product.category)) {
      return false;
    }
    if (criteria.brands.isNotEmpty && !criteria.brands.contains(product.marque)) {
      return false;
    }
    if (criteria.products.isNotEmpty && !criteria.products.contains(product.id)) {
      return false;
    }
    if (criteria.pharmacyIds.isNotEmpty && !criteria.pharmacyIds.contains(user.pharmacyId)) {
      return false;
    }
    if (criteria.zones.isNotEmpty && !criteria.zones.contains(pharmacy.zone)) {
      return false;
    }
    if (criteria.clientCategories.isNotEmpty && !criteria.clientCategories.contains(pharmacy.clientCategory)) {
      return false;
    }
    return true;
  }
}