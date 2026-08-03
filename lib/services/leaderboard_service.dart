import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardPageResult {
  final List<Map<String, dynamic>> users;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  final int totalUsersCount;
  final int currentUserRank;

  LeaderboardPageResult({
    required this.users,
    this.lastDocument,
    required this.hasMore,
    required this.totalUsersCount,
    required this.currentUserRank,
  });
}

class LeaderboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Map<String, String> _pharmacyCategoryCache = {};

  Future<LeaderboardPageResult> getLeaderboardPage({
    String? currentUserId,
    DocumentSnapshot? lastDocument,
    int pageSize = 100,
    int startRank = 0,
  }) async {
    print(
      '🏆 [LEADERBOARD] ===== Fetching Leaderboard Page (pageSize: $pageSize, startRank: $startRank) =====',
    );

    String connectedUserCategory = 'Pharmacie';
    String connectedUserRole = '';
    if (currentUserId != null &&
        currentUserId.isNotEmpty &&
        currentUserId != 'yearly') {
      try {
        final currentUserDoc = await _firestore
            .collection('users')
            .doc(currentUserId)
            .get();
        if (currentUserDoc.exists) {
          connectedUserRole = currentUserDoc.data()?['role'] ?? '';
          String pCat = currentUserDoc.data()?['pharmacyCategory'] as String? ?? '';
          if (pCat.trim().isNotEmpty && pCat.trim() != 'Pharmacie') {
            connectedUserCategory = pCat.trim();
          } else {
            String currPharmacyId = currentUserDoc.data()?['pharmacyId'] ?? '';
            if (currPharmacyId.isNotEmpty) {
              if (_pharmacyCategoryCache.containsKey(currPharmacyId)) {
                String cat = _pharmacyCategoryCache[currPharmacyId]!;
                if (cat.trim().isNotEmpty) {
                  connectedUserCategory = cat.trim();
                }
              } else {
                final currPharmacyDoc = await _firestore
                    .collection('pharmacies')
                    .doc(currPharmacyId)
                    .get();
                if (currPharmacyDoc.exists) {
                  String cat = currPharmacyDoc.data()?['clientCategory'] ?? '';
                  String finalCat = cat.trim().isEmpty ? 'Pharmacie' : cat.trim();
                  _pharmacyCategoryCache[currPharmacyId] = finalCat;
                  if (finalCat != 'Pharmacie') {
                    connectedUserCategory = finalCat;
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        print('❌ [LEADERBOARD] Error reading current user profile: $e');
      }
    }

    Query<Map<String, dynamic>> buildQuery(String orderField) {
      Query<Map<String, dynamic>> q = _firestore
          .collection('users')
          .where('status', isEqualTo: 'active');

      if (connectedUserRole == 'Dermo-conseiller') {
        q = q.where('role', isEqualTo: 'Dermo-conseiller');
      }
      return q.orderBy(orderField, descending: true);
    }

    Query<Map<String, dynamic>> query;
    String primaryOrderField = 'totalPointsValidated';
    try {
      query = buildQuery(primaryOrderField);
    } catch (_) {
      primaryOrderField = 'points';
      query = buildQuery(primaryOrderField);
    }

    try {
      List<Map<String, dynamic>> pageUsers = [];
      DocumentSnapshot? newLastDoc = lastDocument;
      bool hasMore = true;
      int currentRank = startRank;

      while (pageUsers.length < pageSize && hasMore) {
        int fetchLimit = (pageSize - pageUsers.length) + 10;
        Query<Map<String, dynamic>> pageQuery = query.limit(fetchLimit);
        if (newLastDoc != null) {
          pageQuery = pageQuery.startAfterDocument(newLastDoc);
        }

        QuerySnapshot<Map<String, dynamic>> snapshot;
        try {
          snapshot = await pageQuery.get();
        } catch (e) {
          if (primaryOrderField == 'totalPointsValidated') {
            print(
              '⚠️ [LEADERBOARD] totalPointsValidated query failed, falling back to points: $e',
            );
            primaryOrderField = 'points';
            query = buildQuery(primaryOrderField);
            pageQuery = query.limit(fetchLimit);
            if (newLastDoc != null) {
              pageQuery = pageQuery.startAfterDocument(newLastDoc);
            }
            snapshot = await pageQuery.get();
          } else {
            rethrow;
          }
        }

        if (snapshot.docs.isEmpty) {
          hasMore = false;
          break;
        }

        newLastDoc = snapshot.docs.last;

        // Batch check pharmacy IDs only for users missing pharmacyCategory
        Set<String> uncachedPharmacyIds = {};
        for (var userDoc in snapshot.docs) {
          final data = userDoc.data();
          final String uCat = data['pharmacyCategory'] as String? ?? '';
          final String pharmacyId = data['pharmacyId'] as String? ?? '';
          if (uCat.trim().isEmpty && pharmacyId.isNotEmpty && !_pharmacyCategoryCache.containsKey(pharmacyId)) {
            uncachedPharmacyIds.add(pharmacyId);
          }
        }

        if (uncachedPharmacyIds.isNotEmpty) {
          final pharmIdsList = uncachedPharmacyIds.toList();
          final List<Future<QuerySnapshot<Map<String, dynamic>>>> futures = [];
          for (int j = 0; j < pharmIdsList.length; j += 10) {
            final pharmBatch = pharmIdsList.skip(j).take(10).toList();
            futures.add(_firestore
                .collection('pharmacies')
                .where(FieldPath.documentId, whereIn: pharmBatch)
                .get());
          }
          final pSnapshots = await Future.wait(futures);
          for (var pSnap in pSnapshots) {
            for (var pDoc in pSnap.docs) {
              String cat = pDoc.data()['clientCategory'] as String? ?? '';
              _pharmacyCategoryCache[pDoc.id] = cat.trim().isEmpty ? 'Pharmacie' : cat.trim();
            }
          }
        }

        for (var userDoc in snapshot.docs) {
          final data = userDoc.data();
          final uId = userDoc.id;
          final role = data['role'] as String? ?? '';

          // For non-Dermo-conseiller, filter out internal/admin roles
          if (connectedUserRole != 'Dermo-conseiller') {
            if ([
              'Dermo-conseiller',
              'preparateur_manager',
              'mystery',
              'admin',
            ].contains(role)) {
              continue;
            }
          }

          final points =
              (data['totalPointsValidated'] as num?)?.toDouble() ??
              (data['points'] as num?)?.toDouble() ??
              0.0;
          final String pharmacyId = data['pharmacyId'] as String? ?? '';

          String userCategory = data['pharmacyCategory'] as String? ?? '';
          if (userCategory.trim().isEmpty) {
            if (pharmacyId.isNotEmpty) {
              userCategory = _pharmacyCategoryCache[pharmacyId] ?? 'Pharmacie';
            } else {
              userCategory = 'Pharmacie';
            }
          }

          if (connectedUserRole == 'Dermo-conseiller' ||
              connectedUserCategory == userCategory) {
            currentRank++;
            pageUsers.add({
              'userId': uId,
              'name': data['name'] ?? 'Unknown',
              'avatarUrl': data['avatarUrl'] ?? '',
              'points': points.toInt(),
              'totalPointsValidated': points.toInt(),
              'rank': currentRank,
            });

            if (pageUsers.length == pageSize) {
              newLastDoc = userDoc;
              break;
            }
          }
        }

        if (snapshot.docs.length < fetchLimit) {
          hasMore = false;
        }
      }

      int totalUsersCount = 0;
      int currentUserRank = 0;

      if (startRank == 0) {
        // Parallelize total user count query and current user rank calculation
        final List<Future> initialCalculations = [];

        // Task 1: Count total active users
        Query<Map<String, dynamic>> countQuery = _firestore
            .collection('users')
            .where('status', isEqualTo: 'active');
        if (connectedUserRole == 'Dermo-conseiller') {
          countQuery = countQuery.where('role', isEqualTo: 'Dermo-conseiller');
        }
        initialCalculations.add(countQuery.count().get().then((res) {
          totalUsersCount = res.count ?? 0;
        }).catchError((e) {
          print('⚠️ [LEADERBOARD] Count query failed: $e');
        }));

        // Task 2: Calculate rank if user is not in current page
        if (currentUserId != null &&
            currentUserId.isNotEmpty &&
            currentUserId != 'yearly') {
          final inPage = pageUsers.firstWhere(
            (u) => u['userId'] == currentUserId,
            orElse: () => {},
          );
          if (inPage.isNotEmpty) {
            currentUserRank = inPage['rank'];
          } else {
            initialCalculations.add(_firestore.collection('users').doc(currentUserId).get().then((myDoc) async {
              if (myDoc.exists) {
                final myPoints = (myDoc.data()?['totalPointsValidated'] as num?)?.toDouble() ??
                    (myDoc.data()?['points'] as num?)?.toDouble() ??
                    0.0;
                Query<Map<String, dynamic>> higherQuery = _firestore
                    .collection('users')
                    .where('status', isEqualTo: 'active')
                    .where(primaryOrderField, isGreaterThan: myPoints);
                if (connectedUserRole == 'Dermo-conseiller') {
                  higherQuery = higherQuery.where('role', isEqualTo: 'Dermo-conseiller');
                }
                final higherRes = await higherQuery.count().get();
                currentUserRank = (higherRes.count ?? 0) + 1;
              }
            }).catchError((e) {
              print('⚠️ [LEADERBOARD] Rank calculation failed: $e');
            }));
          }
        }

        await Future.wait(initialCalculations);
      }

      return LeaderboardPageResult(
        users: pageUsers,
        lastDocument: newLastDoc,
        hasMore: hasMore,
        totalUsersCount: totalUsersCount,
        currentUserRank: currentUserRank,
      );
    } catch (e) {
      print('❌ [LEADERBOARD] Error: $e');
      return LeaderboardPageResult(
        users: [],
        lastDocument: lastDocument,
        hasMore: false,
        totalUsersCount: 0,
        currentUserRank: 0,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getLeaderboard([
    String? currentUserId,
  ]) async {
    final result = await getLeaderboardPage(
      currentUserId: currentUserId,
      pageSize: 100,
    );
    return result.users;
  }

  static void clearCache([String? period]) {
    _pharmacyCategoryCache.clear();
  }
}
