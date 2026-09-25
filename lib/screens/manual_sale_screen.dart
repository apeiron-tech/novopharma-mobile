import 'package:flutter/material.dart';
import 'package:novopharma/models/product.dart';
import 'package:novopharma/services/product_service.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/services/user_service.dart';
import 'package:novopharma/services/pharmacy_service.dart';
import 'package:novopharma/models/user_model.dart';
import 'package:novopharma/models/challenge.dart';
import 'package:novopharma/services/challenge_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';

class ManualSaleScreen extends StatefulWidget {
  const ManualSaleScreen({super.key});

  @override
  State<ManualSaleScreen> createState() => _ManualSaleScreenState();
}

class _ManualSaleScreenState extends State<ManualSaleScreen> {
  final ProductService _productService = ProductService();
  final UserService _userService = UserService();
  final PharmacyService _pharmacyService = PharmacyService();
  final ChallengeService _challengeService = ChallengeService();
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  List<Challenge> _challenges = [];
  UserModel? _user;
  String? _pharmacyCategory;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _filterProducts();
  }

  void _loadProducts() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.firebaseUser?.uid;

      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final results = await Future.wait([
        _productService.getProducts(),
        _userService.getUser(userId),
        _challengeService.getActiveChallengesList(),
      ]);

      final products = results[0] as List<Product>;
      _user = results[1] as UserModel?;
      _challenges = results[2] as List<Challenge>;

      if (_user != null) {
        String? resolvedPharmacyId;
        if (_user!.role == 'Dermo-conseiller') {
          final prefs = await SharedPreferences.getInstance();
          resolvedPharmacyId = prefs.getString('active_pharmacy_id');
        } else {
          resolvedPharmacyId = _user!.pharmacyId;
        }

        if (resolvedPharmacyId != null && resolvedPharmacyId.isNotEmpty) {
          final pharmacies = await _pharmacyService.getPharmaciesByIds([
            resolvedPharmacyId,
          ]);
          if (pharmacies.isNotEmpty) {
            _pharmacyCategory = pharmacies.first.clientCategory;
          }
        }
      }

      // Filter only enabled products
      _allProducts = products.where((product) => product.isEnabled).toList();
      _filteredProducts = _allProducts;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading products: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredProducts = _allProducts;
      });
    } else {
      setState(() {
        _filteredProducts = _allProducts.where((product) {
          return product.name.toLowerCase().contains(query) ||
              product.sku.toLowerCase().contains(query) ||
              product.marque.toLowerCase().contains(query) ||
              product.category.toLowerCase().contains(query);
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.manualSale),
        backgroundColor: LightModeColors.lightBackground,
        foregroundColor: LightModeColors.dashboardTextPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 4,
        iconTheme: IconThemeData(color: LightModeColors.lightPrimary),
      ),
      backgroundColor: LightModeColors.lightBackground,
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
            child: Container(
              decoration: BoxDecoration(
                color: LightModeColors.lightSurface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: l10n.searchProducts,
                  prefixIcon: const Icon(
                    Icons.search,
                    color: LightModeColors.lightOnSurfaceVariant,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  hintStyle: const TextStyle(
                    color: LightModeColors.lightOnSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),

          // Products list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 80,
                          color: LightModeColors.lightOnSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isEmpty
                              ? 'No products available'
                              : 'No products found',
                          style: const TextStyle(
                            fontSize: 16,
                            color: LightModeColors.lightOnSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      return _buildProductCard(product, l10n);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Challenge? _getMatchingChallenge(Product product) {
    final now = DateTime.now();
    final effectiveCategory = _user?.role == 'Dermo-conseiller'
        ? 'Dermo-conseiller'
        : ((_pharmacyCategory == null || _pharmacyCategory!.isEmpty) ? 'Pharmacie' : _pharmacyCategory!);

    for (var challenge in _challenges) {
      if (challenge.status == 'active' &&
          challenge.hasSalePoints &&
          challenge.productIds.contains(product.id) &&
          !now.isBefore(challenge.startDate) &&
          !now.isAfter(challenge.endDate) &&
          (challenge.clientCategory.contains(effectiveCategory) ||
           (_user?.role == 'Dermo-conseiller' && challenge.clientCategory.contains(_pharmacyCategory ?? 'Pharmacie')))) {
        return challenge;
      }
    }
    return null;
  }

  Widget _buildProductCard(Product product, AppLocalizations l10n) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.pushNamed(
                context,
                '/product',
                arguments: {'id': product.id},
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Product Image
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: LightModeColors.lightBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: LightModeColors.lightOutline),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: product.imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: product.imageUrl,
                              fit: BoxFit.contain,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              errorWidget: (context, url, error) => const Icon(
                                Icons.image_not_supported_outlined,
                              ),
                            )
                          : const Icon(
                              Icons.image_not_supported_outlined,
                              color: LightModeColors.lightOnSurfaceVariant,
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Product Info
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.marque,
                          style: const TextStyle(
                            fontSize: 14,
                            color: LightModeColors.dashboardTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: LightModeColors.warningContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${product.price.toStringAsFixed(3)} TND',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: LightModeColors.warning,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Builder(
                              builder: (context) {
                                final matchingChallenge = _getMatchingChallenge(product);
                                final standardPoints = product.getPoints(_pharmacyCategory, userRole: _user?.role);
                                final pointsToDisplay = matchingChallenge != null ? matchingChallenge.salePoints : standardPoints;
                                
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: matchingChallenge != null 
                                        ? LightModeColors.success.withOpacity(0.12)
                                        : LightModeColors.warningContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (matchingChallenge != null) ...[
                                        const Icon(Icons.celebration_outlined, color: LightModeColors.success, size: 14),
                                        const SizedBox(width: 4),
                                      ],
                                      Text(
                                        '${pointsToDisplay % 1 == 0 ? pointsToDisplay.toInt() : pointsToDisplay} pts',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: matchingChallenge != null ? LightModeColors.success : LightModeColors.warning,
                                        ),
                                      ),
                                      if (matchingChallenge != null) ...[
                                        const SizedBox(width: 4),
                                        Text(
                                          '(Std: $standardPoints)',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: LightModeColors.success.withOpacity(0.7),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
