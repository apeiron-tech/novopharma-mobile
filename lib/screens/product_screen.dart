import 'package:novopharma/widgets/app_network_image.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novopharma/controllers/sales_history_provider.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/controllers/pluxee_redemption_provider.dart';
import 'package:novopharma/models/goal.dart';
import 'package:novopharma/models/pharmacy.dart';
import 'package:novopharma/models/product.dart';
import 'package:novopharma/models/sale.dart';
import 'package:novopharma/models/user_model.dart';
import 'package:novopharma/services/goal_service.dart';
import 'package:novopharma/services/pharmacy_service.dart';
import 'package:novopharma/services/product_service.dart';
import 'package:novopharma/services/user_service.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';
import 'package:novopharma/services/sale_service.dart';
import 'package:novopharma/services/gift_service.dart';
import 'package:novopharma/models/gift.dart';
import 'package:novopharma/models/gift_assignment.dart';
import 'package:novopharma/models/challenge.dart';
import 'package:novopharma/services/challenge_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';

// Helper class to hold all the data fetched for the screen
class _ProductScreenData {
  final Product? product;
  final List<Product> recommendedProducts;
  final List<Goal> allGoals;
  final UserModel? user;
  final Pharmacy? pharmacy;
  final List<Challenge> challenges;

  _ProductScreenData({
    this.product,
    this.recommendedProducts = const [],
    this.allGoals = const [],
    this.user,
    this.pharmacy,
    this.challenges = const [],
  });
}

class ProductScreen extends StatefulWidget {
  final String? sku;
  final String? id;
  final Sale? sale;
  final bool isSelectionMode;
  const ProductScreen({
    super.key,
    this.sku,
    this.id,
    this.sale,
    this.isSelectionMode = false,
  });

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final ProductService _productService = ProductService();
  final GoalService _goalService = GoalService();
  final UserService _userService = UserService();
  final PharmacyService _pharmacyService = PharmacyService();
  final SaleService _saleService = SaleService();
  final ChallengeService _challengeService = ChallengeService();

  late Future<_ProductScreenData> _dataFuture;
  final ValueNotifier<int> _quantityNotifier = ValueNotifier(1);

  @override
  void initState() {
    super.initState();
    if (widget.sale != null) {
      _quantityNotifier.value = widget.sale!.quantity;
    }
    _dataFuture = _loadData();
  }

  @override
  void dispose() {
    _quantityNotifier.dispose();
    super.dispose();
  }

  Future<_ProductScreenData> _loadData() async {
    final product = widget.sale != null
        ? await _productService.getProductById(widget.sale!.productId)
        : widget.id != null
        ? await _productService.getProductById(widget.id!)
        : await _productService.getProductBySku(widget.sku!);
    if (product == null) return _ProductScreenData(product: null);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.firebaseUser?.uid;
    if (userId == null) return _ProductScreenData(product: product);

    final [
      recommendedProducts,
      allGoals,
      user,
      challenges,
    ] = await Future.wait([
      product.recommendedWith.isNotEmpty
          ? _productService.getProductsByIds(product.recommendedWith)
          : Future.value(<Product>[]),
      _goalService.getUserGoals(),
      _userService.getUser(userId),
      _challengeService.getActiveChallengesList(),
    ]);

    Pharmacy? pharmacy;
    final userModel = user as UserModel?;
    String? resolvedPharmacyId;
    if (userModel != null) {
      if (userModel.role == 'Dermo-conseiller') {
        final prefs = await SharedPreferences.getInstance();
        resolvedPharmacyId = prefs.getString('active_pharmacy_id');
      } else {
        resolvedPharmacyId = userModel.pharmacyId;
      }
    }

    if (resolvedPharmacyId != null && resolvedPharmacyId.isNotEmpty) {
      final pharmacies = await _pharmacyService.getPharmaciesByIds([
        resolvedPharmacyId,
      ]);
      if (pharmacies.isNotEmpty) {
        pharmacy = pharmacies.first;
      }
    }

    return _ProductScreenData(
      product: product,
      recommendedProducts: recommendedProducts as List<Product>,
      allGoals: allGoals as List<Goal>,
      user: userModel,
      pharmacy: pharmacy,
      challenges: challenges as List<Challenge>,
    );
  }

  double _getEffectivePoints(
    Product product,
    List<Challenge> challenges,
    String? pharmacyCategory, {
    String? userRole,
  }) {
    final now = DateTime.now();
    final effectiveCategory = userRole == 'Dermo-conseiller'
        ? 'Dermo-conseiller'
        : ((pharmacyCategory == null || pharmacyCategory.isEmpty)
            ? 'Pharmacie'
            : pharmacyCategory);

    for (var challenge in challenges) {
      if (challenge.status == 'active' &&
          challenge.hasSalePoints &&
          challenge.productIds.contains(product.id) &&
          !now.isBefore(challenge.startDate) &&
          !now.isAfter(challenge.endDate) &&
          (challenge.clientCategory.contains(effectiveCategory) ||
           (userRole == 'Dermo-conseiller' && challenge.clientCategory.contains(pharmacyCategory ?? 'Pharmacie')))) {
        return challenge.salePoints;
      }
    }
    return product.getPoints(pharmacyCategory, userRole: userRole);
  }

  Challenge? _getMatchingChallenge(
    Product product,
    List<Challenge> challenges,
    String? pharmacyCategory, {
    String? userRole,
  }) {
    final now = DateTime.now();
    final effectiveCategory = userRole == 'Dermo-conseiller'
        ? 'Dermo-conseiller'
        : ((pharmacyCategory == null || pharmacyCategory.isEmpty)
            ? 'Pharmacie'
            : pharmacyCategory);

    for (var challenge in challenges) {
      if (challenge.status == 'active' &&
          challenge.hasSalePoints &&
          challenge.productIds.contains(product.id) &&
          !now.isBefore(challenge.startDate) &&
          !now.isAfter(challenge.endDate) &&
          (challenge.clientCategory.contains(effectiveCategory) ||
           (userRole == 'Dermo-conseiller' && challenge.clientCategory.contains(pharmacyCategory ?? 'Pharmacie')))) {
        return challenge;
      }
    }
    return null;
  }

  List<Product> _getEligibleProductsForGift(
    Gift gift,
    List<Product> allProducts,
  ) {
    return allProducts.where((p) {
      if (p.isDisabled) return false;
      bool matches = true;
      if (gift.listProducts.isNotEmpty && !gift.listProducts.contains(p.id)) {
        matches = false;
      }
      if (matches &&
          gift.productCategory.isNotEmpty &&
          !gift.productCategory.contains(p.category)) {
        matches = false;
      }
      if (matches &&
          gift.productMarque.isNotEmpty &&
          !gift.productMarque.contains(p.marque)) {
        matches = false;
      }
      return matches;
    }).toList();
  }

  Future<Map<Product, int>?> _showProductSelectionDialog({
    required List<Product> eligibleProducts,
    required Product primaryProduct,
  }) async {
    final Map<Product, int> selectedProducts = {};
    final searchController = TextEditingController();
    final listToShow = eligibleProducts
        .where((p) => p.id != primaryProduct.id)
        .toList();

    return showDialog<Map<Product, int>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final query = searchController.text.toLowerCase();
            final filteredList = listToShow.where((p) {
              return p.name.toLowerCase().contains(query) ||
                  p.marque.toLowerCase().contains(query) ||
                  p.category.toLowerCase().contains(query);
            }).toList();

            final screenWidth = MediaQuery.of(context).size.width;
            final screenHeight = MediaQuery.of(context).size.height;

            final totalSelectedQty =
                selectedProducts.values.fold(0, (total, q) => total + q);
            final totalSelectedAmount = selectedProducts.entries.fold(
              0.0,
              (total, e) => total + (e.key.price * e.value),
            );

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: LightModeColors.lightSurface,
              clipBehavior: Clip.antiAlias,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 20,
              ),
              child: SizedBox(
                width: screenWidth > 450 ? 420 : screenWidth * 0.92,
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: screenHeight * 0.82,
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with icon, title, count & close button
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: LightModeColors.lightPrimary
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.add_shopping_cart,
                              color: LightModeColors.lightPrimary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Produits éligibles",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        LightModeColors.dashboardTextPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "${listToShow.length} produit${listToShow.length > 1 ? 's' : ''} disponible${listToShow.length > 1 ? 's' : ''}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color:
                                        LightModeColors.dashboardTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, size: 20),
                            color: LightModeColors.dashboardTextSecondary,
                            splashRadius: 18,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Instruction tip chip
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: LightModeColors.lightBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: LightModeColors.lightOutlineVariant,
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.touch_app_outlined,
                              size: 14,
                              color: LightModeColors.dashboardTextSecondary,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                "Touchez pour cocher • Appui long pour détails",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: LightModeColors
                                      .dashboardTextSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Search field
                      TextField(
                        controller: searchController,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: "Rechercher par nom, marque...",
                          hintStyle: const TextStyle(
                            fontSize: 12,
                            color: LightModeColors.dashboardTextSecondary,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            size: 18,
                            color: LightModeColors.dashboardTextSecondary,
                          ),
                          suffixIcon: searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  color:
                                      LightModeColors.dashboardTextSecondary,
                                  onPressed: () {
                                    searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          fillColor: LightModeColors.lightBackground,
                          filled: true,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: LightModeColors.lightOutlineVariant,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: LightModeColors.lightOutlineVariant,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: LightModeColors.lightPrimary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Product List
                      Expanded(
                        child: filteredList.isEmpty
                            ? const Center(
                                child: Text(
                                  "Aucun produit éligible trouvé",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: LightModeColors
                                        .dashboardTextSecondary,
                                  ),
                                ),
                              )
                            : Scrollbar(
                                thumbVisibility: filteredList.length > 3,
                                child: ListView.separated(
                                  itemCount: filteredList.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final p = filteredList[index];
                                    final isSelected =
                                        selectedProducts.containsKey(p);
                                    final currentQty =
                                        selectedProducts[p] ?? 1;

                                    return Container(
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? LightModeColors.lightPrimary
                                                .withOpacity(0.06)
                                            : LightModeColors.lightBackground,
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isSelected
                                              ? LightModeColors.lightPrimary
                                              : LightModeColors
                                                  .lightOutlineVariant
                                                  .withOpacity(0.8),
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                      ),
                                      child: InkWell(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        onTap: () {
                                          setState(() {
                                            if (isSelected) {
                                              selectedProducts.remove(p);
                                            } else {
                                              selectedProducts[p] = 1;
                                            }
                                          });
                                        },
                                        onLongPress: () async {
                                          final result =
                                              await Navigator.push<
                                                Map<Product, int>
                                              >(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      ProductScreen(
                                                        id: p.id,
                                                        isSelectionMode: true,
                                                      ),
                                                ),
                                              );
                                          if (result != null &&
                                              result.isNotEmpty) {
                                            setState(() {
                                              selectedProducts[p] =
                                                  result.values.first;
                                            });
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: Row(
                                            children: [
                                              // Thumbnail
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: Container(
                                                  width: 48,
                                                  height: 48,
                                                  color: Colors.white,
                                                  child: AppNetworkImage(
                                                    imageUrl: p.imageUrl,
                                                    width: 48,
                                                    height: 48,
                                                    fit: BoxFit.contain,
                                                    memCacheWidth: 150,
                                                    memCacheHeight: 150,
                                                    errorIcon: Icons
                                                        .image_not_supported_outlined,
                                                    errorIconSize: 22,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),

                                              // Title, Marque & Price
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    if (p.marque
                                                        .isNotEmpty) ...[
                                                      Text(
                                                        p.marque.toUpperCase(),
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: LightModeColors
                                                              .lightPrimary
                                                              .withOpacity(
                                                                0.85,
                                                              ),
                                                          letterSpacing: 0.5,
                                                        ),
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                      ),
                                                      const SizedBox(
                                                        height: 2,
                                                      ),
                                                    ],
                                                    Text(
                                                      p.name,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 13,
                                                        color: LightModeColors
                                                            .dashboardTextPrimary,
                                                        height: 1.25,
                                                      ),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      "${p.price.toStringAsFixed(3)} TND",
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: LightModeColors
                                                            .dashboardTextSecondary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),

                                              // Checkbox / Stepper
                                              if (isSelected)
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    border: Border.all(
                                                      color: LightModeColors
                                                          .lightPrimary
                                                          .withOpacity(0.3),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                      MainAxisSize.min,
                                                    children: [
                                                      InkWell(
                                                        onTap: () {
                                                          setState(() {
                                                            if (currentQty >
                                                                1) {
                                                              selectedProducts[p] =
                                                                  currentQty -
                                                                      1;
                                                            } else {
                                                              selectedProducts
                                                                  .remove(p);
                                                            }
                                                          });
                                                        },
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        child: const Padding(
                                                          padding:
                                                              EdgeInsets.all(
                                                                6,
                                                              ),
                                                          child: Icon(
                                                            Icons.remove,
                                                            size: 16,
                                                            color:
                                                                LightModeColors
                                                                    .lightPrimary,
                                                          ),
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                              horizontal: 4,
                                                            ),
                                                        child: Text(
                                                          '$currentQty',
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 13,
                                                                color:
                                                                    LightModeColors
                                                                        .lightPrimary,
                                                              ),
                                                        ),
                                                      ),
                                                      InkWell(
                                                        onTap: () {
                                                          setState(() {
                                                            selectedProducts[p] =
                                                                currentQty +
                                                                    1;
                                                          });
                                                        },
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        child: const Padding(
                                                          padding:
                                                              EdgeInsets.all(
                                                                6,
                                                              ),
                                                          child: Icon(
                                                            Icons.add,
                                                            size: 16,
                                                            color:
                                                                LightModeColors
                                                                    .lightPrimary,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              else
                                                Container(
                                                  width: 26,
                                                  height: 26,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: LightModeColors
                                                          .lightOutline,
                                                      width: 1.5,
                                                    ),
                                                    color: Colors.white,
                                                  ),
                                                  child: const Icon(
                                                    Icons.add,
                                                    size: 16,
                                                    color: LightModeColors
                                                        .dashboardTextSecondary,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),

                      // Selected summary badge
                      if (selectedProducts.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: LightModeColors.lightPrimary.withOpacity(
                              0.08,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "$totalSelectedQty article${totalSelectedQty > 1 ? 's' : ''} sélectionné${totalSelectedQty > 1 ? 's' : ''}",
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: LightModeColors.lightPrimary,
                                ),
                              ),
                              Text(
                                "${totalSelectedAmount.toStringAsFixed(3)} TND",
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: LightModeColors.lightPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Action Buttons
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: LightModeColors.lightOutline,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                "Annuler",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: LightModeColors
                                      .dashboardTextSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: selectedProducts.isEmpty
                                  ? null
                                  : () => Navigator.pop(
                                      context,
                                      selectedProducts,
                                    ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: LightModeColors.lightPrimary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade300,
                                disabledForegroundColor: Colors.grey.shade500,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    selectedProducts.isEmpty
                                        ? "Valider"
                                        : "Valider ($totalSelectedQty)",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _showSaleConfirmationDialog({
    required Map<Product, int> productsToSell,
    required double totalPrice,
    double? totalPoints,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final totalItemsCount =
        productsToSell.values.fold(0, (total, q) => total + q);

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: LightModeColors.lightSurface,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: screenWidth > 450 ? 420 : screenWidth * 0.92,
            constraints: BoxConstraints(
              maxHeight: screenHeight * 0.82,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: LightModeColors.lightPrimary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.receipt_long_outlined,
                          color: LightModeColors.lightPrimary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Confirmer la vente",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: LightModeColors.dashboardTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "$totalItemsCount article${totalItemsCount > 1 ? 's' : ''} • ${productsToSell.length} référence${productsToSell.length > 1 ? 's' : ''}",
                              style: const TextStyle(
                                fontSize: 13,
                                color: LightModeColors.dashboardTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context, false),
                        icon: const Icon(Icons.close, size: 20),
                        color: LightModeColors.dashboardTextSecondary,
                        splashRadius: 20,
                        tooltip: l10n.cancel,
                      ),
                    ],
                  ),
                ),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: LightModeColors.lightOutlineVariant,
                ),

                // Scrollable Products List
                Flexible(
                  child: Scrollbar(
                    thumbVisibility: productsToSell.length > 3,
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: productsToSell.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final entry = productsToSell.entries.elementAt(index);
                        final p = entry.key;
                        final qty = entry.value;
                        final itemTotal = p.price * qty;

                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: LightModeColors.lightBackground,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: LightModeColors.lightOutlineVariant
                                  .withOpacity(0.8),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Product Image
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  color: Colors.white,
                                  child: AppNetworkImage(
                                    imageUrl: p.imageUrl,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.contain,
                                    memCacheWidth: 150,
                                    memCacheHeight: 150,
                                    errorIcon:
                                        Icons.image_not_supported_outlined,
                                    errorIconSize: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Name and Marque
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (p.marque.isNotEmpty) ...[
                                      Text(
                                        p.marque.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: LightModeColors.lightPrimary
                                              .withOpacity(0.85),
                                          letterSpacing: 0.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                    ],
                                    Text(
                                      p.name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: LightModeColors
                                            .dashboardTextPrimary,
                                        height: 1.25,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${p.price.toStringAsFixed(3)} TND / unité",
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: LightModeColors
                                            .dashboardTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Quantity Pill & Subtotal
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: LightModeColors.lightPrimary
                                          .withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: LightModeColors.lightPrimary
                                            .withOpacity(0.18),
                                      ),
                                    ),
                                    child: Text(
                                      "× $qty",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: LightModeColors.lightPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${itemTotal.toStringAsFixed(3)} TND",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          LightModeColors.dashboardTextPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Summary Card
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: LightModeColors.lightBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: LightModeColors.lightOutlineVariant,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Total articles",
                            style: TextStyle(
                              fontSize: 13,
                              color: LightModeColors.dashboardTextSecondary,
                            ),
                          ),
                          Text(
                            "$totalItemsCount",
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: LightModeColors.dashboardTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      if (totalPoints != null && totalPoints > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.stars_rounded,
                                  size: 16,
                                  color: LightModeColors.success,
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  "Points cumulés",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        LightModeColors.dashboardTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    LightModeColors.success.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "+${totalPoints % 1 == 0 ? totalPoints.toInt() : totalPoints.toStringAsFixed(1)} pts",
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: LightModeColors.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: LightModeColors.lightOutlineVariant,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Montant total",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: LightModeColors.dashboardTextPrimary,
                            ),
                          ),
                          Text(
                            "${totalPrice.toStringAsFixed(3)} TND",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: LightModeColors.lightPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Action Buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: LightModeColors.lightOutline,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            l10n.cancel,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: LightModeColors.dashboardTextSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: LightModeColors.lightPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 18,
                                color: Colors.white,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Confirmer la vente",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return confirmed ?? false;
  }

  Future<void> _submitSale(
    Product product,
    UserModel user,
    String? pharmacyCategory,
    List<Challenge> challenges,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final int quantity = _quantityNotifier.value;
    final double unitPoints = _getEffectivePoints(
      product,
      challenges,
      pharmacyCategory,
      userRole: user.role,
    );
    final double totalPrice = product.price * quantity;

    String? activeVisitId;
    String? activePharmacyId;
    String? activePointOfSale;

    if (user.role == 'Dermo-conseiller') {
      final prefs = await SharedPreferences.getInstance();
      activeVisitId = prefs.getString('active_visit_id');
      activePharmacyId = prefs.getString('active_pharmacy_id');
      activePointOfSale = prefs.getString('active_point_of_sale');

      if (activeVisitId == null || activePharmacyId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Vous devez effectuer un check-in dans une pharmacie avant de pouvoir enregistrer ou modifier une vente.",
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Verify visit is still active in Firestore
      try {
        final visitDoc = await FirebaseFirestore.instance
            .collection('visits_history')
            .doc(activeVisitId)
            .get();

        if (!visitDoc.exists || visitDoc.data()?['status'] != 'active') {
          // The visit is no longer active, clear local storage
          await prefs.remove('active_visit_id');
          await prefs.remove('active_pharmacy_id');
          await prefs.remove('active_pharmacy_name');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Votre session de visite a expiré ou n'est plus active. Veuillez faire un nouveau check-in.",
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Erreur de validation de la visite: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    Future<List<String>> performSave(Map<Product, int> productsToSell) async {
      List<String> saleIds = [];
      for (var entry in productsToSell.entries) {
        final p = entry.key;
        final qty = entry.value;
        final pUnitPoints = _getEffectivePoints(
          p,
          challenges,
          pharmacyCategory,
          userRole: user.role,
        );
        final pTotalPrice = p.price * qty;

        final resolvedPointOfSale = user.role == 'Dermo-conseiller'
            ? activePointOfSale
            : user.pointOfSale;

        String saleId;
        if (widget.sale != null && p.id == product.id) {
          // Update existing sale for primary product
          final updatedSale = Sale(
            id: widget.sale!.id,
            userId: user.uid,
            pharmacyId: user.role == 'Dermo-conseiller'
                ? activePharmacyId!
                : user.pharmacyId,
            productId: p.id,
            productNameSnapshot: p.name,
            quantity: qty,
            pointsEarned: pUnitPoints * qty,
            saleDate: widget.sale!.saleDate, // Keep original sale date
            totalPrice: pTotalPrice,
            productBrandSnapshot: p.marque,
            productCategorySnapshot: p.category,
            status: widget.sale!.status, // Keep original status
            visitId: user.role == 'Dermo-conseiller'
                ? activeVisitId
                : widget.sale!.visitId,
            pointOfSaleSnapshot: user.role == 'Dermo-conseiller'
                ? activePointOfSale
                : (widget.sale!.pointOfSaleSnapshot ?? user.pointOfSale),
          );
          Provider.of<SalesHistoryProvider>(
            context,
            listen: false,
          ).updateSale(widget.sale!, updatedSale);
          saleId = widget.sale!.id;
        } else {
          // Create new sale
          final newSale = Sale(
            id: '', // Firestore will generate ID
            userId: user.uid,
            pharmacyId: user.role == 'Dermo-conseiller'
                ? activePharmacyId!
                : user.pharmacyId,
            productId: p.id,
            productNameSnapshot: p.name,
            quantity: qty,
            pointsEarned: pUnitPoints * qty,
            saleDate: DateTime.now(),
            totalPrice: pTotalPrice,
            productBrandSnapshot: p.marque,
            productCategorySnapshot: p.category,
            status: 'pending',
            visitId: user.role == 'Dermo-conseiller' ? activeVisitId : null,
            pointOfSaleSnapshot: resolvedPointOfSale,
          );
          saleId = await _saleService.createSale(newSale);
        }
        saleIds.add(saleId);
      }
      return saleIds;
    }

    // Check for gifts if it's a new sale or existing sale
    final giftService = GiftService();
    final String targetPharmacyId = user.role == 'Dermo-conseiller'
        ? activePharmacyId!
        : user.pharmacyId;
    final List<GiftAssignment> assignments = user.role == 'Dermo-conseiller'
        ? await giftService.getAssignmentsForDermoOrPharmacy(
            pharmacyId: targetPharmacyId,
            dermoId: user.uid,
          )
        : await giftService.getAssignmentsForPharmacy(targetPharmacyId);

    // 1. Check for Trade Offer Reminders
    int finalQuantity = quantity;
    Gift? potentialTradeGift;
    int? neededQty;
    int? targetQty;
    for (var assignment in assignments) {
      final gift = await giftService.getGiftById(assignment.giftId);
      if (gift != null && gift.status == 'active') {
        bool matchesProduct = true;
        if (gift.listProducts.isNotEmpty &&
            !gift.listProducts.contains(product.id)) {
          matchesProduct = false;
        }
        if (matchesProduct &&
            gift.productCategory.isNotEmpty &&
            !gift.productCategory.contains(product.category)) {
          matchesProduct = false;
        }
        if (matchesProduct &&
            gift.productMarque.isNotEmpty &&
            !gift.productMarque.contains(product.marque)) {
          matchesProduct = false;
        }

        if (matchesProduct) {
          if (gift.thresholdType == 'products') {
            final minQty = gift.minProductsCount ?? 1;
            if (quantity < minQty) {
              potentialTradeGift = gift;
              neededQty = minQty - quantity;
              targetQty = minQty;
              break; // Just prompt for the first matching offer found
            }
          } else if (gift.thresholdType == 'amount') {
            final minAmt = gift.minPurchaseAmount ?? 0.0;
            if (totalPrice < minAmt && product.price > 0) {
              final minQty = (minAmt / product.price).ceil();
              if (quantity < minQty) {
                potentialTradeGift = gift;
                neededQty = minQty - quantity;
                targetQty = minQty;
                break; // Just prompt for the first matching offer found
              }
            }
          }
        }
      }
    }

    Map<Product, int> productsToSell = {product: quantity};

    if (potentialTradeGift != null &&
        neededQty != null &&
        neededQty > 0 &&
        targetQty != null) {
      final gift = potentialTradeGift;
      final dynamic adjustResult = await showDialog<dynamic>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          final screenWidth = MediaQuery.of(context).size.width;

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            backgroundColor: LightModeColors.lightSurface,
            clipBehavior: Clip.antiAlias,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 24,
            ),
            child: SizedBox(
              width: screenWidth > 450 ? 420 : screenWidth * 0.92,
              child: Stack(
                children: [
                  SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (gift.imageUrl.isNotEmpty)
                          Stack(
                            children: [
                              CachedNetworkImage(
                                imageUrl: gift.imageUrl,
                                height: 175,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  height: 175,
                                  color: LightModeColors.lightBackground,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: LightModeColors.lightPrimary,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  height: 175,
                                  color: LightModeColors.lightBackground,
                                  child: const Icon(
                                    Icons.card_giftcard,
                                    size: 54,
                                    color: LightModeColors.lightPrimary,
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withOpacity(0.35),
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.15),
                                      ],
                                      stops: const [0.0, 0.5, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(top: 24.0),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: LightModeColors.lightPrimary
                                    .withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.card_giftcard,
                                color: LightModeColors.lightPrimary,
                                size: 44,
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                "Rappel Offre Trade",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: LightModeColors.dashboardTextPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text.rich(
                                TextSpan(
                                  text: "Ce produit fait partie de l'offre : ",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color:
                                        LightModeColors.dashboardTextSecondary,
                                    height: 1.35,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: gift.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: LightModeColors
                                            .dashboardTextPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (gift.description.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: LightModeColors.lightPrimary
                                        .withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: LightModeColors.lightPrimary
                                          .withOpacity(0.18),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(7),
                                        decoration: BoxDecoration(
                                          color: LightModeColors.lightPrimary
                                              .withOpacity(0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.card_giftcard,
                                          size: 18,
                                          color: LightModeColors.lightPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          gift.description,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: LightModeColors
                                                .dashboardTextPrimary,
                                            height: 1.35,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final allProducts =
                                        await _productService.getProducts();
                                    final eligible =
                                        _getEligibleProductsForGift(
                                      gift,
                                      allProducts,
                                    );
                                    if (context.mounted) {
                                      final selected =
                                          await _showProductSelectionDialog(
                                        eligibleProducts: eligible,
                                        primaryProduct: product,
                                      );
                                      if (selected != null) {
                                        Navigator.pop(context, selected);
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        LightModeColors.lightPrimary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_shopping_cart,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        "Ajouter d'autres produits éligibles",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                          color: LightModeColors.lightOutline,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 13,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                      child: const Text(
                                        "Continuer sans cadeau",
                                        style: TextStyle(
                                          color: LightModeColors
                                              .dashboardTextSecondary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            LightModeColors.lightPrimary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 13,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.add,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "Ajuster à $targetQty",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        decoration: BoxDecoration(
                          color: gift.imageUrl.isNotEmpty
                              ? Colors.black.withOpacity(0.45)
                              : LightModeColors.lightBackground,
                          shape: BoxShape.circle,
                          border: gift.imageUrl.isNotEmpty
                              ? Border.all(
                                  color: Colors.white.withOpacity(0.25),
                                  width: 0.8,
                                )
                              : null,
                        ),
                        padding: const EdgeInsets.all(7),
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: gift.imageUrl.isNotEmpty
                              ? Colors.white
                              : LightModeColors.dashboardTextSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (adjustResult == null) {
        return; // User closed dialog with back button, cancel sale
      }
      if (adjustResult == true) {
        _quantityNotifier.value = targetQty;
        finalQuantity = targetQty;
        productsToSell[product] = finalQuantity;
      } else if (adjustResult is Map<Product, int>) {
        adjustResult.forEach((p, qty) {
          productsToSell[p] = qty;
          finalQuantity += qty;
        });
      }
    }

    double finalTotalPrice = 0.0;
    double finalTotalPoints = 0.0;
    productsToSell.forEach((p, qty) {
      finalTotalPrice += p.price * qty;
      finalTotalPoints +=
          _getEffectivePoints(p, challenges, pharmacyCategory, userRole: user.role) * qty;
    });

    // 2. Show the "Confirmer la vente" dialog first (in all scenarios)
    final confirmSale = await _showSaleConfirmationDialog(
      productsToSell: productsToSell,
      totalPrice: finalTotalPrice,
      totalPoints: finalTotalPoints,
    );
    if (!confirmSale) {
      return; // Exit without saving if cancelled or back pressed
    }

    // 3. Evaluate valid/eligible gifts based on productsToSell
    List<Map<String, dynamic>> validGiftsData = [];

    for (var assignment in assignments) {
      final gift = await giftService.getGiftById(assignment.giftId);
      if (gift != null && gift.status == 'active') {
        int giftMatchingQty = 0;
        double giftMatchingAmt = 0.0;

        for (var entry in productsToSell.entries) {
          final p = entry.key;
          final qty = entry.value;

          bool matchesProduct = true;
          if (gift.listProducts.isNotEmpty &&
              !gift.listProducts.contains(p.id)) {
            matchesProduct = false;
          }
          if (matchesProduct &&
              gift.productCategory.isNotEmpty &&
              !gift.productCategory.contains(p.category)) {
            matchesProduct = false;
          }
          if (matchesProduct &&
              gift.productMarque.isNotEmpty &&
              !gift.productMarque.contains(p.marque)) {
            matchesProduct = false;
          }

          if (matchesProduct) {
            giftMatchingQty += qty;
            giftMatchingAmt += p.price * qty;
          }
        }

        if (giftMatchingQty > 0) {
          bool isThresholdMet = true;
          if (gift.thresholdType == 'products') {
            final minQty = gift.minProductsCount ?? 1;
            if (giftMatchingQty < minQty) {
              isThresholdMet = false;
            }
          } else if (gift.thresholdType == 'amount') {
            final minAmt = gift.minPurchaseAmount ?? 0.0;
            if (giftMatchingAmt < minAmt) {
              isThresholdMet = false;
            }
          }

          if (isThresholdMet) {
            validGiftsData.add({'assignment': assignment, 'gift': gift});
          }
        }
      }
    }

    // 4. Save the sale
    final savedSaleIds = await performSave(productsToSell);
    final savedSaleId = savedSaleIds.first;

    // 5. If gifts are available, show the "confirm gift" popup
    if (validGiftsData.isNotEmpty) {
      Map<String, Map<String, dynamic>> groupedGifts = {};
      for (var data in validGiftsData) {
        final assignment = data['assignment'] as GiftAssignment;
        final key = "${assignment.giftId}_${assignment.assigneeId}";

        if (!groupedGifts.containsKey(key)) {
          groupedGifts[key] = {
            'gift': data['gift'],
            'assignment': assignment,
            'totalStock': assignment.assignedStock,
          };
        } else {
          groupedGifts[key]!['totalStock'] += assignment.assignedStock;
          final existingAssignment =
              groupedGifts[key]!['assignment'] as GiftAssignment;
          final existingCreatedAt =
              existingAssignment.createdAt ?? DateTime.now();
          final currentCreatedAt = assignment.createdAt ?? DateTime.now();
          if (currentCreatedAt.isBefore(existingCreatedAt)) {
            groupedGifts[key]!['assignment'] = assignment;
          }
        }
      }

      final availableGifts = groupedGifts.values.toList();

      final giveGift = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: LightModeColors.lightSurface,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: LightModeColors.lightPrimary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.card_giftcard_rounded,
                    color: LightModeColors.lightPrimary,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.giftAvailableTitle,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: LightModeColors.dashboardTextPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.giftAvailableMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: LightModeColors.dashboardTextSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: LightModeColors.lightOutline,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          l10n.noThanks,
                          style: const TextStyle(
                            color: LightModeColors.dashboardTextSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LightModeColors.lightPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          l10n.yesOffer,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      if (giveGift == true) {
        await _showGiftSelectionDialog(
          availableGifts,
          savedSaleIds,
          user.role == 'Dermo-conseiller' ? activePharmacyId! : user.pharmacyId,
          user.uid,
          user.role == 'Dermo-conseiller'
              ? activePointOfSale
              : user.pointOfSale,
          giftService,
          finalQuantity,
          finalTotalPrice,
          visitId: activeVisitId,
        );
      }
    }

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.saleSuccessMessage),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    Navigator.of(context).pop();
  }

  Future<void> _showGiftSelectionDialog(
    List<Map<String, dynamic>> availableGifts,
    List<String> saleIds,
    String pharmacyId,
    String userId,
    String? pointOfSale,
    GiftService giftService,
    int quantity,
    double totalPrice, {
    String? visitId,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final formKey = GlobalKey<FormState>();
    final quantityController = TextEditingController();
    int quantityCount = 1;
    String? nomClient;
    String? prenomClient;
    String? phoneNumber;
    Map<String, dynamic>? selectedGiftData = availableGifts.first;

    // Helper function to calculate default gift quantity
    int calculateDefaultQty(Map<String, dynamic> data) {
      final gift = data['gift'] as Gift;
      final totalStock = data['totalStock'] as int;
      int calculated = 1;
      if (gift.thresholdType == 'products') {
        final minProducts = gift.minProductsCount ?? 1;
        if (minProducts > 0) {
          calculated = (gift.isCumulative ?? false)
              ? (quantity ~/ minProducts)
              : 1;
        }
      } else if (gift.thresholdType == 'amount') {
        final minAmt = gift.minPurchaseAmount ?? 0.0;
        if (minAmt > 0) {
          calculated = (gift.isCumulative ?? false)
              ? (totalPrice ~/ minAmt)
              : 1;
        }
      }
      if (calculated > totalStock) calculated = totalStock;
      if (calculated < 1) calculated = 1;
      return calculated;
    }

    // Set initial text
    if (selectedGiftData != null) {
      quantityController.text = '${calculateDefaultQty(selectedGiftData!)}';
    }

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: LightModeColors.lightSurface,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: LightModeColors.lightPrimary.withOpacity(
                                  0.1,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.card_giftcard,
                                color: LightModeColors.lightPrimary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              l10n.offerGift,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: LightModeColors.dashboardTextPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        Text(
                          l10n.selectGift,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: LightModeColors.dashboardTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<Map<String, dynamic>>(
                          value: selectedGiftData,
                          isExpanded: true,
                          decoration: InputDecoration(
                            fillColor: LightModeColors.lightBackground,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                          ),
                          items: availableGifts.map((data) {
                            final gift = data['gift'] as Gift;
                            final totalStock = data['totalStock'] as int;
                            final assignment =
                                data['assignment'] as GiftAssignment;
                            final String sourceType =
                                assignment.assigneeType == 'Dermo-conseiller'
                                ? "Stock personnel"
                                : "Stock pharmacie";
                            return DropdownMenuItem(
                              value: data,
                              child: Text(
                                '${gift.title} (Stock: $totalStock - $sourceType)',
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedGiftData = value;
                              if (value != null) {
                                quantityController.text =
                                    '${calculateDefaultQty(value)}';
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        Text(
                          l10n.quantity,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: LightModeColors.dashboardTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: quantityController,
                          readOnly: true,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            fillColor: LightModeColors.lightBackground,
                            hintText: l10n.giftQuantityHint,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return l10n.fieldRequired;
                            final intVal = int.tryParse(value);
                            if (intVal == null || intVal <= 0)
                              return l10n.fieldInvalid;
                            if (selectedGiftData != null) {
                              final totalStock =
                                  selectedGiftData!['totalStock'] as int;
                              if (intVal > totalStock)
                                return l10n.insufficientStock;
                            }
                            return null;
                          },
                          onSaved: (value) => quantityCount = int.parse(value!),
                        ),
                        const SizedBox(height: 16),

                        Text(
                          l10n.clientInfoOptional,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: LightModeColors.dashboardTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          decoration: InputDecoration(
                            fillColor: LightModeColors.lightBackground,
                            hintText: l10n.lastName,
                            prefixIcon: const Icon(
                              Icons.person_outline,
                              size: 20,
                            ),
                          ),
                          onSaved: (value) => nomClient = value,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          decoration: InputDecoration(
                            fillColor: LightModeColors.lightBackground,
                            hintText: l10n.firstName,
                            prefixIcon: const Icon(
                              Icons.person_outline,
                              size: 20,
                            ),
                          ),
                          onSaved: (value) => prenomClient = value,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            fillColor: LightModeColors.lightBackground,
                            hintText: l10n.phone,
                            prefixIcon: const Icon(
                              Icons.phone_outlined,
                              size: 20,
                            ),
                          ),
                          onSaved: (value) => phoneNumber = value,
                        ),
                        const SizedBox(height: 32),

                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: Text(
                                  l10n.cancel,
                                  style: const TextStyle(
                                    color:
                                        LightModeColors.dashboardTextSecondary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (formKey.currentState!.validate()) {
                                    formKey.currentState!.save();
                                    if (selectedGiftData != null) {
                                      final gift =
                                          selectedGiftData!['gift'] as Gift;
                                      final assignment =
                                          selectedGiftData!['assignment']
                                              as GiftAssignment;
                                      await _handleGiftSubmission(
                                        saleIds: saleIds,
                                        giftId: gift.id,
                                        pharmacyId: pharmacyId,
                                        quantity: quantityCount,
                                        clientNom: nomClient,
                                        clientPrenom: prenomClient,
                                        clientPhone: phoneNumber,
                                        userId: userId,
                                        pointOfSale: pointOfSale,
                                        giftService: giftService,
                                        l10n: l10n,
                                        context: context,
                                        assignmentId: assignment.id,
                                        visitId: visitId,
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: LightModeColors.lightPrimary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  l10n.confirm,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    quantityController.dispose();
  }

  Future<void> _handleGiftSubmission({
    required List<String> saleIds,
    required String giftId,
    required String pharmacyId,
    required int quantity,
    required String? clientNom,
    required String? clientPrenom,
    required String? clientPhone,
    required String userId,
    required String? pointOfSale,
    required GiftService giftService,
    required AppLocalizations l10n,
    required BuildContext context,
    String? assignmentId,
    String? visitId,
  }) async {
    try {
      await giftService.saveGiftOperation(
        saleId: saleIds.first,
        saleIds: saleIds,
        giftId: giftId,
        pharmacyId: pharmacyId,
        quantity: quantity,
        clientNom: clientNom,
        clientPrenom: clientPrenom,
        clientPhone: clientPhone,
        userId: userId,
        pointOfSale: pointOfSale,
        assignmentId: assignmentId,
        visitId: visitId,
      );
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.giftRecordedSuccess),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorOccurred(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scannedProduct),
        backgroundColor: LightModeColors.lightBackground,
        foregroundColor: LightModeColors.dashboardTextPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_in_talk_rounded),
            onPressed: () async {
              final Uri telLaunchUri = Uri(scheme: 'tel', path: '+21698667540');
              if (await canLaunchUrl(telLaunchUri)) {
                await launchUrl(telLaunchUri);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      backgroundColor: LightModeColors.lightBackground,
      body: FutureBuilder<_ProductScreenData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final data = snapshot.data!;
          final product = data.product;
          final user = data.user;
          final pharmacy = data.pharmacy;

          if (product == null) return Center(child: Text('Product not found.'));
          if (user == null || pharmacy == null) {
            if (user?.role == 'Dermo-conseiller' && pharmacy == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.pin_drop_rounded,
                        size: 80,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "Check-in Requis",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: LightModeColors.dashboardTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Vous devez effectuer un check-in dans une pharmacie avant de pouvoir enregistrer une vente ou consulter un produit.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: LightModeColors.dashboardTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(
                            context,
                          ).pushReplacementNamed('/dashboard_home');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LightModeColors.lightPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Aller au Tableau de Bord",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Center(child: Text('Could not load user profile.'));
          }

          // Check if product is disabled
          if (product.isDisabled) {
            return _buildDisabledProductView(l10n, product);
          }

          final relatedGoals = _goalService.findMatchingGoals(
            product,
            data.allGoals,
          );

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Image and Basic Info
                      _buildProductHeader(product),
                      const SizedBox(height: 24),

                      // Sale Details Card (Quantity & Price)
                      _buildModernSaleCard(
                        l10n,
                        product,
                        pharmacy.clientCategory,
                        data.challenges,
                        userRole: user.role,
                      ),
                      const SizedBox(height: 24),

                      // Description
                      if (product.description.isNotEmpty) ...[
                        _buildModernSection(
                          l10n.description,
                          Icons.article_outlined,
                          product.description,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Usage Tips (Conseil d'utilisation)
                      if (product.protocol.isNotEmpty) ...[
                        _buildModernSection(
                          l10n.usageTips,
                          Icons.lightbulb_outline,
                          product.protocol,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Protocol (Recommendé avec)
                      if (data.recommendedProducts.isNotEmpty) ...[
                        _buildModernSectionTitle(
                          l10n.protocol,
                          Icons.local_hospital_outlined,
                        ),
                        const SizedBox(height: 12),
                        _buildRecommendedProductsList(data.recommendedProducts),
                        const SizedBox(height: 16),
                      ],

                      // Composition
                      if (product.composition.isNotEmpty) ...[
                        _buildModernSection(
                          l10n.composition,
                          Icons.science_outlined,
                          product.composition,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Related Goals (Objectifs associés)
                      if (relatedGoals.isNotEmpty) ...[
                        _buildModernSectionTitle(
                          l10n.relatedGoals,
                          Icons.flag_outlined,
                        ),
                        const SizedBox(height: 12),
                        ...relatedGoals.map(
                          (goal) => _buildModernGoalCard(
                            goal,
                            product,
                            user,
                            pharmacy,
                          ),
                        ),
                      ],

                      const SizedBox(height: 100), // Space for bottom bar
                    ],
                  ),
                ),
              ),
              _buildModernActionBar(
                l10n,
                product,
                user,
                pharmacy.clientCategory,
                data.challenges,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProductHeader(Product product) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            LightModeColors.lightPrimary,
            LightModeColors.lightSecondary,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: LightModeColors.lightPrimary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          if (product.imageUrl.isNotEmpty)
            Container(
              height: 280,
              width: double.infinity,
              decoration: BoxDecoration(
                color: LightModeColors.lightSurface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                child: AppNetworkImage(
                  imageUrl: product.imageUrl,
                  height: 280,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  memCacheWidth: 800,
                  memCacheHeight: 800,
                  errorIcon: Icons.image_not_supported_outlined,
                  errorIconSize: 80,
                  errorIconColor: const Color(0xFFE0E0E0),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: LightModeColors.lightOnPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        product.marque,
                        style: const TextStyle(
                          fontSize: 14,
                          color: LightModeColors.lightOnPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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

  Widget _buildModernSaleCard(
    AppLocalizations l10n,
    Product product,
    String? pharmacyCategory,
    List<Challenge> challenges, {
    String? userRole,
  }) {
    final activeChallenge = _getMatchingChallenge(
      product,
      challenges,
      pharmacyCategory,
      userRole: userRole,
    );

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        children: [
          // Quantity Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: LightModeColors.warning,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.shopping_cart_outlined,
                      color: LightModeColors.lightOnPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.quantity,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF102132),
                    ),
                  ),
                ],
              ),
              ValueListenableBuilder<int>(
                valueListenable: _quantityNotifier,
                builder: (context, quantity, child) {
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F8FB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.remove_circle,
                            color: quantity > 1
                                ? LightModeColors.warning
                                : LightModeColors.lightOnSurfaceVariant,
                          ),
                          onPressed: () {
                            if (quantity > 1) _quantityNotifier.value--;
                          },
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: LightModeColors.lightSurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$quantity',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF102132),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle,
                            color: LightModeColors.warning,
                          ),
                          onPressed: () {
                            _quantityNotifier.value++;
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 16),
          // Points Display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: LightModeColors.success.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.stars_rounded,
                      color: LightModeColors.success,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Points',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: LightModeColors.dashboardTextPrimary,
                    ),
                  ),
                ],
              ),
              ValueListenableBuilder<int>(
                valueListenable: _quantityNotifier,
                builder: (context, quantity, child) {
                  final currentChallenge = _getMatchingChallenge(
                    product,
                    challenges,
                    pharmacyCategory,
                    userRole: userRole,
                  );
                  final standardPoints = product.getPoints(pharmacyCategory, userRole: userRole);
                  final pointsPerUnit = currentChallenge != null
                      ? currentChallenge.salePoints
                      : standardPoints;
                  final pointsEarned = pointsPerUnit * quantity;

                  // Format to remove trailing .0 for whole numbers
                  final pointsText = pointsEarned % 1 == 0
                      ? pointsEarned.toInt().toString()
                      : pointsEarned.toString();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        pointsText,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: LightModeColors.success,
                        ),
                      ),
                      if (currentChallenge != null)
                        Text(
                          "($pointsPerUnit pts/u vs Standard: $standardPoints)",
                          style: const TextStyle(
                            fontSize: 11,
                            color: LightModeColors.success,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
          // Optional: Matching Challenge Badge
          if (activeChallenge != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: LightModeColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: LightModeColors.success.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.celebration_outlined,
                    color: LightModeColors.success,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Challenge: ${activeChallenge!.title}",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: LightModeColors.success,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModernSectionTitle(String title, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LightModeColors.warning,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F9BD1).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSection(String title, IconData icon, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: LightModeColors.warning,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: LightModeColors.lightOnPrimary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: LightModeColors.lightOnPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: LightModeColors.lightOnPrimary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
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
          child: Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              color: LightModeColors.dashboardTextSecondary,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendedProductsList(List<Product> products) {
    return SizedBox(
      height: 240,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductScreen(id: product.id),
                ),
              );
            },
            child: Container(
              width: 180,
              margin: const EdgeInsets.only(right: 16),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: Container(
                      height: 140,
                      width: double.infinity,
                      color: LightModeColors.lightBackground,
                      child: AppNetworkImage(
                        imageUrl: product.imageUrl,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        memCacheWidth: 400,
                        memCacheHeight: 400,
                        errorIcon: Icons.image_not_supported_outlined,
                        errorIconSize: 40,
                        errorIconColor: const Color(0xFFE0E0E0),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: LightModeColors.dashboardTextPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            product.marque,
                            style: const TextStyle(
                              fontSize: 12,
                              color: LightModeColors.dashboardTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernGoalCard(
    Goal goal,
    Product product,
    UserModel user,
    Pharmacy pharmacy,
  ) {
    return FutureBuilder<bool>(
      future: _goalService.isUserEligibleForGoal(goal, product, user, pharmacy),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final isEligible = snapshot.data ?? false;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isEligible
                  ? [LightModeColors.success, LightModeColors.successContainer]
                  : [
                      LightModeColors.lightError,
                      LightModeColors.lightErrorContainer,
                    ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color:
                    (isEligible
                            ? LightModeColors.success
                            : LightModeColors.lightError)
                        .withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isEligible ? Icons.check_circle : Icons.cancel,
                  color: LightModeColors.lightOnPrimary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: LightModeColors.lightOnPrimary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEligible ? "Eligible" : "Not eligible",
                      style: TextStyle(
                        color: LightModeColors.lightOnPrimary.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModernActionBar(
    AppLocalizations l10n,
    Product product,
    UserModel user,
    String? pharmacyCategory,
    List<Challenge> challenges,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LightModeColors.lightSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Price row at the top, aligned to the left
            Align(
              alignment: Alignment.centerLeft,
              child: ValueListenableBuilder<int>(
                valueListenable: _quantityNotifier,
                builder: (context, quantity, child) {
                  // Display only the unit price (fixed, not multiplied)
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.recommendedPrice,
                        style: const TextStyle(
                          fontSize: 13,
                          color: LightModeColors.dashboardTextSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Padding(
                        padding: const EdgeInsets.only(left: 6.0),
                        child: Text(
                          '${product.price.toStringAsFixed(3)} TND',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF102132),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16), // Space between price and button
            // Button row at the bottom, centered
            ElevatedButton(
              onPressed: widget.isSelectionMode
                  ? () => Navigator.pop(context, {
                      product: _quantityNotifier.value,
                    })
                  : () => _submitSale(
                      product,
                      user,
                      pharmacyCategory,
                      challenges,
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.isSelectionMode
                    ? LightModeColors.lightPrimary
                    : LightModeColors.lightError,
                foregroundColor: widget.isSelectionMode
                    ? Colors.white
                    : LightModeColors.lightOnError,
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.isSelectionMode
                        ? Icons.add_shopping_cart
                        : Icons.check_circle_outline,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.isSelectionMode
                        ? "Ajouter à la vente"
                        : (widget.sale != null
                              ? l10n.updateSale
                              : l10n.confirmSale),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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

  Widget _buildDisabledProductView(AppLocalizations l10n, Product product) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Product Image
            if (product.imageUrl.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.grey.withOpacity(0.5),
                      BlendMode.saturation,
                    ),
                    child: CachedNetworkImage(
                      imageUrl: product.imageUrl,
                      height: 200,
                      width: 200,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) => Container(
                        height: 200,
                        width: 200,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported, size: 80),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 32),

            // Disabled Icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: LightModeColors.lightErrorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.block,
                color: LightModeColors.lightError,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),

            // Product Name
            Text(
              product.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: LightModeColors.dashboardTextPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // Product Brand
            Text(
              product.marque,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: LightModeColors.dashboardTextSecondary,
              ),
            ),
            const SizedBox(height: 32),

            // Warning Container
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: LightModeColors.lightErrorContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: LightModeColors.lightErrorContainer,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: LightModeColors.lightError,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.productNotAvailable,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: LightModeColors.lightError,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.productNotAvailableMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: LightModeColors.lightError,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Back Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: LightModeColors.lightPrimary,
                  foregroundColor: LightModeColors.lightOnPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  l10n.goBack,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
