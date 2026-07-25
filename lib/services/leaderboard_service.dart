import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> getLeaderboard([
    String? currentUserId,
  ]) async {
    print('🏆 [LEADERBOARD] ===== Starting Leaderboard Fetch =====');

    String connectedUserCategory = 'Pharmacie';
    String connectedUserRole = '';
    if (currentUserId != null) {
      final currentUserDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();
      if (currentUserDoc.exists) {
        connectedUserRole = currentUserDoc.data()?['role'] ?? '';
        String currPharmacyId = currentUserDoc.data()?['pharmacyId'] ?? '';
        if (currPharmacyId.isNotEmpty) {
          final currPharmacyDoc = await _firestore
              .collection('pharmacies')
              .doc(currPharmacyId)
              .get();
          if (currPharmacyDoc.exists) {
            String cat = currPharmacyDoc.data()?['clientCategory'] ?? '';
            if (cat != 'Pharmacie' && cat != '') {
              connectedUserCategory = cat; // E.g., 'Para-Pharmacie'
            }
          }
        }
      }
    }

    Query<Map<String, dynamic>> query = _firestore
        .collection('users')
        .where('status', isEqualTo: 'active');

    if (connectedUserRole == 'Dermo-conseiller') {
      query = query
          .where('role', isEqualTo: 'Dermo-conseiller')
          .orderBy('points', descending: true);
    } else {
      query = query
          .where('role', whereNotIn: ['Dermo-conseiller', 'preparateur_manager', 'mystery', 'admin'])
          .orderBy('role')
          .orderBy('points', descending: true);
    }

    try {
      final usersSnapshot = await query.get();

      print(
        '🏆 [LEADERBOARD] ===== Users Snapshot: ${usersSnapshot.docs.length} =====',
      );
      final List<Map<String, dynamic>> leaderboard = [];

      // Batch check pharmacy IDs
      Set<String> thisBatchPharmacyIds = {};
      for (var userDoc in usersSnapshot.docs) {
        final data = userDoc.data();
        final String pharmacyId = data['pharmacyId'] as String? ?? '';
        if (pharmacyId.isNotEmpty) {
          thisBatchPharmacyIds.add(pharmacyId);
        }
      }

      Map<String, String> pharmacyCategoryMap = {};
      if (thisBatchPharmacyIds.isNotEmpty) {
        final pharmIdsList = thisBatchPharmacyIds.toList();
        for (int j = 0; j < pharmIdsList.length; j += 10) {
          final pharmBatch = pharmIdsList.skip(j).take(10).toList();
          final pharmSnapshot = await _firestore
              .collection('pharmacies')
              .where(FieldPath.documentId, whereIn: pharmBatch)
              .get();
          for (var pDoc in pharmSnapshot.docs) {
            pharmacyCategoryMap[pDoc.id] =
                pDoc.data()['clientCategory'] as String? ?? '';
          }
        }
      }

      for (var userDoc in usersSnapshot.docs) {
        final data = userDoc.data();
        final uId = userDoc.id;
        final points = data['points'] is num
            ? (data['points'] as num).toDouble()
            : 0.0;
        final String pharmacyId = data['pharmacyId'] as String? ?? '';

        String userCategory = 'Pharmacie';
        if (pharmacyId.isNotEmpty) {
          String cat = pharmacyCategoryMap[pharmacyId] ?? '';
          if (cat != 'Pharmacie' && cat != '') {
            userCategory = cat; // E.g., 'Para-Pharmacie'
          }
        }

        // For non-Dermo-conseiller, we also filter by pharmacy category.
        // For Dermo-conseiller, we show all Dermo-conseiller users globally.
        if (connectedUserRole == 'Dermo-conseiller' || connectedUserCategory == userCategory) {
          leaderboard.add({
            'userId': uId,
            'name': data['name'] ?? 'Unknown',
            'avatarUrl': data['avatarUrl'] ?? '',
            'points': points.toInt(),
          });
        }
      }

      // Since Firestore requires ordering by 'role' first when using 'whereNotIn',
      // we must sort by points descending locally for non-Dermo-conseiller users.
      if (connectedUserRole != 'Dermo-conseiller') {
        leaderboard.sort((a, b) => b['points'].compareTo(a['points']));
      }

      // Assign sequential ranks after sorting
      for (int i = 0; i < leaderboard.length; i++) {
        leaderboard[i]['rank'] = i + 1;
      }

      return leaderboard;
    } catch (e) {
      print('❌ [LEADERBOARD] Error: $e');
      return [];
    }
  }

  // Define clearCache purely to prevent external compilation errors if called elsewhere
  static void clearCache([String? period]) {}
}
