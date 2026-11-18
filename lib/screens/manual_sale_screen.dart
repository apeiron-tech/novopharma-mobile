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
import 'package:novopharma/design/design.dart';

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

  // Presentation only: the first screenful arrives once; rows created later
  // (scrolling back, a new search) appear immediately.
  bool _listArrived = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: InkAppBar(
        title: l10n.manualSale,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            // Search bar
            child: AppSearchField(
              controller: _searchController,
              hintText: l10n.searchProducts,
              onDark: true,
            ),
          ),
        ),
      ),
      body: AppBackground(
        accent: Tone.peach,
        // Products list
        child: _isLoading
            ? const Align(
                alignment: Alignment.topCenter,
                child: SkeletonList(
                  count: 6,
                  itemHeight: 104,
                  padding: EdgeInsets.fromLTRB(16, 18, 16, 16),
                ),
              )
            : _filteredProducts.isEmpty
            ? EmptyState(
                icon: Icons.search_off_rounded,
                tone: Tone.peach,
                title: _searchController.text.isEmpty
                    ? 'No products available'
                    : 'No products found',
              )
            : Builder(
                builder: (context) {
                  if (!_listArrived) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _listArrived = true,
                    );
                  }
                  return ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      16,
                      18,
                      16,
                      MediaQuery.paddingOf(context).bottom + 24,
                    ),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      final card = _buildProductCard(product, l10n);
                      if (index > 5) return card;
                      return Entrance(
                        delay: _listArrived
                            ? Duration.zero
                            : Duration(milliseconds: 60 * index),
                        duration:
                            _listArrived ? Duration.zero : AppMotion.slow,
                        child: card,
                      );
                    },
                  );
                },
              ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        radius: AppRadii.md + 2,
        padding: const EdgeInsets.all(12),
        semanticLabel: product.name,
        onTap: () {
          Navigator.pushNamed(
            context,
            '/product',
            arguments: {'id': product.id},
          );
        },
        child: Row(
          children: [
            // Product Image
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              clipBehavior: Clip.antiAlias,
              child: product.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: product.imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) =>
                          const SkeletonBox(height: 76, radius: 0),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.image_not_supported_rounded,
                        color: AppColors.textFaint,
                      ),
                    )
                  : const Icon(
                      Icons.image_not_supported_rounded,
                      color: AppColors.textFaint,
                    ),
            ),
            const SizedBox(width: 14),

            // Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: AppText.body(
                      size: 15.5,
                      weight: FontWeight.w700,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    product.marque,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label(size: 13, letterSpacing: 0),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${product.price.toStringAsFixed(3)} TND',
                        style: AppText.display(size: 15.5),
                      ),
                      Builder(
                        builder: (context) {
                          final matchingChallenge = _getMatchingChallenge(product);
                          final standardPoints = product.getPoints(_pharmacyCategory, userRole: _user?.role);
                          final pointsToDisplay = matchingChallenge != null ? matchingChallenge.salePoints : standardPoints;

                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TonePill(
                                label:
                                    '${pointsToDisplay % 1 == 0 ? pointsToDisplay.toInt() : pointsToDisplay} pts',
                                tone: matchingChallenge != null
                                    ? Tone.indigo
                                    : Tone.mint,
                                icon: matchingChallenge != null
                                    ? Icons.celebration_rounded
                                    : null,
                              ),
                              if (matchingChallenge != null) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '(Std: $standardPoints)',
                                  style: AppText.label(
                                    size: 11.5,
                                    weight: FontWeight.w500,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textFaint,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
