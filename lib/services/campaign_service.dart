import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:novopharma/models/campaign.dart';
import 'package:novopharma/models/product.dart';

class CampaignService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'campaigns';

  Future<List<Campaign>> getActiveCampaigns() async {
    try {
      final now = DateTime.now();
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('startDate', isLessThanOrEqualTo: now)
          .where('endDate', isGreaterThanOrEqualTo: now)
          .get();
      final List<Campaign> campaigns = querySnapshot.docs
          .map((doc) => Campaign.fromFirestore(doc))
          .toList();
      return campaigns;
    } catch (e) {
      print('Error fetching campaigns: $e');
      return [];
    }
  }

  Future<List<Campaign>> findMatchingCampaigns(Product product) async {
    try {
      final now = DateTime.now();
      // This is a client-side filter because Firestore doesn't support
      // querying multiple array-contains on different fields.
      // For larger datasets, a more advanced backend solution (like a Cloud Function)
      // would be more efficient.
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('startDate', isLessThanOrEqualTo: now)
          .where('endDate', isGreaterThanOrEqualTo: now)
          .get();

      final List<Campaign>
      campaigns = querySnapshot.docs.map((doc) => Campaign.fromFirestore(doc)).where((
        campaign,
      ) {
        final criteria = campaign.productCriteria;
        if (criteria == null) return false;

        final matchesProduct = criteria.products?.contains(product.id) ?? false;
        final matchesBrand =
            criteria.marques?.contains(product.marque) ?? false;
        final matchesCategory =
            criteria.categories?.contains(product.category) ?? false;

        // If any list is empty, it's considered a non-match for that criteria.
        // The logic is: match if the product is in the specific list OR if the list is null/empty (wildcard).
        // However, the prompt implies filtering, so we assume non-empty lists are the target.
        bool productOk = criteria.products?.isNotEmpty == true
            ? matchesProduct
            : false;
        bool brandOk = criteria.marques?.isNotEmpty == true
            ? matchesBrand
            : false;
        bool categoryOk = criteria.categories?.isNotEmpty == true
            ? matchesCategory
            : false;

        return productOk || brandOk || categoryOk;
      }).toList();

      return campaigns;
    } catch (e) {
      print('Error finding matching campaigns: $e');
      return [];
    }
  }
}
