import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/models/challenge.dart';
import 'package:novopharma/models/product.dart';
import 'package:novopharma/models/user_model.dart';
import 'package:novopharma/services/challenge_service.dart';
import 'package:novopharma/services/pharmacy_service.dart';
import 'package:novopharma/services/product_service.dart';
import 'package:novopharma/services/user_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import 'product_screen.dart';

class _ChallengeDetailsData {
  final Challenge? challenge;
  final List<Product> products;
  final String? userCategory;
  final String? userRole;

  _ChallengeDetailsData({this.challenge, this.products = const [], this.userCategory, this.userRole});
}

class ChallengeDetailsScreen extends StatefulWidget {
  final String challengeId;
  const ChallengeDetailsScreen({super.key, required this.challengeId});

  @override
  State<ChallengeDetailsScreen> createState() => _ChallengeDetailsScreenState();
}

class _ChallengeDetailsScreenState extends State<ChallengeDetailsScreen> {
  final ChallengeService _challengeService = ChallengeService();
  final ProductService _productService = ProductService();
  final UserService _userService = UserService();
  final PharmacyService _pharmacyService = PharmacyService();

  late Future<_ChallengeDetailsData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_ChallengeDetailsData> _loadData() async {
    final challenge = await _challengeService.getChallengeById(widget.challengeId);
    if (challenge == null) return _ChallengeDetailsData(challenge: null);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.firebaseUser?.uid;

    final [products, user] = await Future.wait([
      challenge.productIds.isNotEmpty
          ? _productService.getProductsByIds(challenge.productIds)
          : Future.value(<Product>[]),
      userId != null ? _userService.getUser(userId) : Future.value(null),
    ]);

    String? category;
    final userModel = user as UserModel?;
    if (userModel != null) {
      String? resolvedPharmacyId;
      if (userModel.role == 'Dermo-conseiller') {
        final prefs = await SharedPreferences.getInstance();
        resolvedPharmacyId = prefs.getString('active_pharmacy_id');
      } else {
        resolvedPharmacyId = userModel.pharmacyId;
      }

      if (resolvedPharmacyId != null && resolvedPharmacyId.isNotEmpty) {
        final pharmacy = await _pharmacyService.getPharmacy(resolvedPharmacyId);
        final cat = pharmacy?.clientCategory;
        category = (cat == null || cat.isEmpty) ? 'Pharmacie' : cat;
      } else {
        category = 'Pharmacie';
      }
    } else {
      category = 'Pharmacie';
    }

    return _ChallengeDetailsData(
      challenge: challenge,
      products: products as List<Product>,
      userCategory: category,
      userRole: userModel?.role,
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: LightModeColors.lightBackground,
      appBar: AppBar(
        title: const Text(
          "Challenge",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: -0.5,
            color: LightModeColors.dashboardTextPrimary,
          ),
        ),
        backgroundColor: LightModeColors.lightBackground,
        elevation: 0,
        centerTitle: true,
      ),
      body: FutureBuilder<_ChallengeDetailsData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data?.challenge == null) {
            return const Center(child: Text("Erreur lors du chargement des données."));
          }

          final data = snapshot.data!;
          final challenge = data.challenge!;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildChallengeHero(challenge),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle("Description"),
                      const SizedBox(height: 12),
                      Text(
                        challenge.description,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[800],
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle("Produits du challenge"),
                      const SizedBox(height: 16),
                       ...data.products.map((product) => _buildProductCard(context, product, data.userCategory, challenge, userRole: data.userRole)),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChallengeHero(Challenge challenge) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: challenge.imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.grey[200]),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                  ),
                ),
              ),
              // Status Overlay
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: LightModeColors.success.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    "CHALLENGE ACTIF",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge.title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: LightModeColors.dashboardTextPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildInfoCard(
                      Icons.calendar_today_rounded,
                      "Début",
                      _formatDate(challenge.startDate),
                    ),
                    const SizedBox(width: 12),
                    _buildInfoCard(
                      Icons.event_available_rounded,
                      "Fin",
                      _formatDate(challenge.endDate),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: LightModeColors.lightBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: LightModeColors.lightPrimary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: LightModeColors.lightPrimary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.grey[500],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: LightModeColors.dashboardTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: LightModeColors.warning,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: LightModeColors.dashboardTextPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(BuildContext context, Product product, String? category, Challenge challenge, {String? userRole}) {
    final now = DateTime.now();
    double points = product.getPoints(category, userRole: userRole);
    
    // Check if we should use challenge points
    final effectiveCategory = userRole == 'Dermo-conseiller'
        ? 'Dermo-conseiller'
        : ((category == null || category.isEmpty) ? 'Pharmacie' : category);

    if (challenge.status == 'active' && 
        challenge.hasSalePoints && 
        !now.isBefore(challenge.startDate) && 
        !now.isAfter(challenge.endDate) &&
        (challenge.clientCategory.contains(effectiveCategory) ||
         (userRole == 'Dermo-conseiller' && challenge.clientCategory.contains(category ?? 'Pharmacie')) ||
         (category == 'Pharmacie' && challenge.clientCategory.contains('')))) {
      points = challenge.salePoints;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductScreen(id: product.id),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 70,
                    height: 70,
                    color: Colors.grey[50],
                    child: CachedNetworkImage(
                      imageUrl: product.imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Icon(Icons.image_outlined, color: Colors.grey),
                      errorWidget: (context, url, error) => const Icon(Icons.broken_image_outlined, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: LightModeColors.dashboardTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${product.marque} • ${product.category}",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: LightModeColors.success.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "${points % 1 == 0 ? points.toInt() : points} pts",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: LightModeColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }
}
