import 'package:novopharma/widgets/app_network_image.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:novopharma/design/design.dart';
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
import 'package:novopharma/controllers/basket_provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
                borderRadius: BorderRadius.circular(AppRadii.xl),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 20,
              ),
              child: _DialogPane(
                child: SizedBox(
                  width: screenWidth > 450 ? 420 : screenWidth * 0.92,
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: screenHeight * 0.82,
                    ),
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with icon, title, count & close button
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const TintIcon(
                              icon: Icons.add_shopping_cart_rounded,
                              tone: Tone.peach,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Produits éligibles",
                                    style: AppText.display(size: 19),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    "${listToShow.length} produit${listToShow.length > 1 ? 's' : ''} disponible${listToShow.length > 1 ? 's' : ''}",
                                    style: AppText.label(
                                      size: 12.5,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _DialogCloseButton(
                              onTap: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Instruction tip chip
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.indigoTint,
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.touch_app_rounded,
                                size: 16,
                                color: AppColors.indigoDeep,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Touchez pour cocher • Appui long pour détails",
                                  style: AppText.label(
                                    size: 12.5,
                                    color: AppColors.indigoDeep,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Search field
                        AppSearchField(
                          controller: searchController,
                          hintText: "Rechercher par nom, marque...",
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),

                        // Product List
                        Expanded(
                          child: filteredList.isEmpty
                              ? Center(
                                  child: Text(
                                    "Aucun produit éligible trouvé",
                                    textAlign: TextAlign.center,
                                    style: AppText.body(
                                      size: 14,
                                      color: AppColors.textMuted,
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

                                      return Pressable(
                                        pressedScale: 0.98,
                                        semanticLabel: p.name,
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
                                        child: AnimatedContainer(
                                          duration: AppMotion.fast,
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? AppColors.indigoTint
                                                : Colors.white.withValues(
                                                    alpha: 0.78,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              AppRadii.md,
                                            ),
                                            border: Border.all(
                                              color: isSelected
                                                  ? AppColors.indigo
                                                  : Colors.white,
                                              width: isSelected ? 1.6 : 1,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Row(
                                                children: [
                                                  // Thumbnail
                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          AppRadii.xs,
                                                        ),
                                                    child: Container(
                                                      width: 52,
                                                      height: 52,
                                                      color: Colors.white,
                                                      child: AppNetworkImage(
                                                        imageUrl: p.imageUrl,
                                                        width: 52,
                                                        height: 52,
                                                        fit: BoxFit.contain,
                                                        memCacheWidth: 150,
                                                        memCacheHeight: 150,
                                                        errorIcon: Icons
                                                            .image_not_supported_outlined,
                                                        errorIconSize: 22,
                                                        errorIconColor:
                                                            AppColors.textFaint,
                                                        backgroundColor:
                                                            Colors.white,
                                                        placeholder:
                                                            (context, url) =>
                                                                const SkeletonBox(
                                                                  width: 52,
                                                                  height: 52,
                                                                  radius: 0,
                                                                ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),

                                                  // Title, Marque & Price
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        if (p.marque
                                                            .isNotEmpty) ...[
                                                          Text(
                                                            p.marque,
                                                            style: AppText.label(
                                                              size: 11.5,
                                                              weight:
                                                                  FontWeight.w700,
                                                              color: AppColors
                                                                  .indigo,
                                                              letterSpacing: 0,
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
                                                          style: AppText.body(
                                                            size: 14,
                                                            weight:
                                                                FontWeight.w600,
                                                            height: 1.25,
                                                          ),
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          "${p.price.toStringAsFixed(3)} TND",
                                                          style:
                                                              AppText.display(
                                                                size: 13.5,
                                                                color: AppColors
                                                                    .textMuted,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),

                                                  // Checkbox
                                                  AnimatedContainer(
                                                    duration: AppMotion.fast,
                                                    width: 28,
                                                    height: 28,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: isSelected
                                                            ? AppColors.indigo
                                                            : AppColors
                                                                .lineStrong,
                                                        width: 1.5,
                                                      ),
                                                      color: isSelected
                                                          ? AppColors.indigo
                                                          : Colors.white,
                                                    ),
                                                    child: Icon(
                                                      isSelected
                                                          ? Icons.check_rounded
                                                          : Icons.add_rounded,
                                                      size: 17,
                                                      color: isSelected
                                                          ? Colors.white
                                                          : AppColors.textMuted,
                                                    ),
                                                  ),
                                                ],
                                              ),

                                              // Stepper
                                              if (isSelected)
                                                Align(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                          top: 8,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.all(3),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            AppRadii.pill,
                                                          ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        _RoundStepButton(
                                                          icon: Icons
                                                              .remove_rounded,
                                                          semanticLabel: '-',
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
                                                        ),
                                                        ConstrainedBox(
                                                          constraints:
                                                              const BoxConstraints(
                                                                minWidth: 40,
                                                              ),
                                                          child: Text(
                                                            '$currentQty',
                                                            textAlign: TextAlign
                                                                .center,
                                                            style:
                                                                AppText.display(
                                                                  size: 18,
                                                                ),
                                                          ),
                                                        ),
                                                        _RoundStepButton(
                                                          icon:
                                                              Icons.add_rounded,
                                                          semanticLabel: '+',
                                                          onTap: () {
                                                            setState(() {
                                                              selectedProducts[p] =
                                                                  currentQty +
                                                                  1;
                                                            });
                                                          },
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
                                ),
                        ),

                        // Selected summary badge
                        if (selectedProducts.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.indigoTint,
                              borderRadius: BorderRadius.circular(AppRadii.sm),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    "$totalSelectedQty article${totalSelectedQty > 1 ? 's' : ''} sélectionné${totalSelectedQty > 1 ? 's' : ''}",
                                    style: AppText.label(
                                      size: 13,
                                      weight: FontWeight.w700,
                                      color: AppColors.indigoDeep,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  "${totalSelectedAmount.toStringAsFixed(3)} TND",
                                  style: AppText.display(
                                    size: 15,
                                    color: AppColors.indigoDeep,
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
                              flex: 2,
                              child: SecondaryButton(
                                label: "Annuler",
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: PrimaryButton(
                                label: selectedProducts.isEmpty
                                    ? "Valider"
                                    : "Valider ($totalSelectedQty)",
                                height: 52,
                                onPressed: selectedProducts.isEmpty
                                    ? null
                                    : () => Navigator.pop(
                                        context,
                                        selectedProducts,
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
            borderRadius: BorderRadius.circular(AppRadii.xl),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          clipBehavior: Clip.antiAlias,
          child: _DialogPane(
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
                    padding: const EdgeInsets.fromLTRB(18, 16, 10, 14),
                    child: Row(
                      children: [
                        const TintIcon(
                          icon: Icons.receipt_long_rounded,
                          tone: Tone.peach,
                          size: 46,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Confirmer la vente",
                                style: AppText.display(size: 20),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                "$totalItemsCount article${totalItemsCount > 1 ? 's' : ''} • ${productsToSell.length} référence${productsToSell.length > 1 ? 's' : ''}",
                                style: AppText.label(
                                  size: 13,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _DialogCloseButton(
                          tooltip: l10n.cancel,
                          onTap: () => Navigator.pop(context, false),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.ink.withValues(alpha: 0.08),
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
                              color: Colors.white.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(AppRadii.md),
                              border: Border.all(color: Colors.white),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Product Image
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.xs,
                                  ),
                                  child: Container(
                                    width: 52,
                                    height: 52,
                                    color: Colors.white,
                                    child: AppNetworkImage(
                                      imageUrl: p.imageUrl,
                                      width: 52,
                                      height: 52,
                                      fit: BoxFit.contain,
                                      memCacheWidth: 150,
                                      memCacheHeight: 150,
                                      errorIcon:
                                          Icons.image_not_supported_outlined,
                                      errorIconSize: 22,
                                      errorIconColor: AppColors.textFaint,
                                      backgroundColor: Colors.white,
                                      placeholder: (context, url) =>
                                          const SkeletonBox(
                                            width: 52,
                                            height: 52,
                                            radius: 0,
                                          ),
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
                                          p.marque,
                                          style: AppText.label(
                                            size: 11.5,
                                            weight: FontWeight.w700,
                                            color: AppColors.indigo,
                                            letterSpacing: 0,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                      ],
                                      Text(
                                        p.name,
                                        style: AppText.body(
                                          size: 14,
                                          weight: FontWeight.w600,
                                          height: 1.25,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "${p.price.toStringAsFixed(3)} TND / unité",
                                        style: AppText.label(
                                          size: 12,
                                          weight: FontWeight.w500,
                                          letterSpacing: 0,
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
                                    TonePill(
                                      label: "× $qty",
                                      tone: Tone.peach,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      "${itemTotal.toStringAsFixed(3)} TND",
                                      style: AppText.display(size: 14),
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
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: Colors.white),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Total articles",
                              style: AppText.body(
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              "$totalItemsCount",
                              style: AppText.display(size: 15),
                            ),
                          ],
                        ),
                        if (totalPoints != null && totalPoints > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.stars_rounded,
                                    size: 18,
                                    color: AppColors.mint,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Points cumulés",
                                    style: AppText.body(
                                      size: 14,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                "+${totalPoints % 1 == 0 ? totalPoints.toInt() : totalPoints.toStringAsFixed(1)} pts",
                                style: AppText.display(
                                  size: 18,
                                  color: AppColors.mintDeep,
                                ),
                              ),
                            ],
                          ),
                        ],
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Divider(
                            height: 1,
                            thickness: 1,
                            color: AppColors.ink.withValues(alpha: 0.08),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Montant total",
                              style: AppText.body(
                                size: 15,
                                weight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              "${totalPrice.toStringAsFixed(3)} TND",
                              style: AppText.display(size: 21),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Action Buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PrimaryButton(
                          label: "Confirmer la vente",
                          icon: Icons.check_circle_outline_rounded,
                          gradient: Tone.peach.gradient,
                          glowColor: AppColors.peach,
                          foreground: AppColors.ink,
                          onPressed: () => Navigator.pop(context, true),
                        ),
                        const SizedBox(height: 8),
                        SecondaryButton(
                          label: l10n.cancel,
                          height: 48,
                          onPressed: () => Navigator.pop(context, false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
              backgroundColor: AppColors.coralDeep,
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
                backgroundColor: AppColors.coralDeep,
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
              backgroundColor: AppColors.coralDeep,
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
            basketId: widget.sale!.basketId,
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
              borderRadius: BorderRadius.circular(AppRadii.xl),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 24,
            ),
            child: _DialogPane(
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
                                    color: AppColors.amberTint,
                                    child: const Center(
                                      child: CapsuleLoader(
                                        size: 36,
                                        left: AppColors.amber,
                                        right: AppColors.peach,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        height: 175,
                                        color: AppColors.amberTint,
                                        child: const Icon(
                                          Icons.card_giftcard_rounded,
                                          size: 54,
                                          color: AppColors.amberDeep,
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
                                          AppColors.ink.withValues(alpha: 0.38),
                                          AppColors.ink.withValues(alpha: 0),
                                          AppColors.ink.withValues(alpha: 0.16),
                                        ],
                                        stops: const [0.0, 0.5, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.only(top: 28.0),
                              child: BlisterIcon(
                                icon: Icons.card_giftcard_rounded,
                                tone: Tone.amber,
                                size: 76,
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Rappel Offre Trade",
                                  textAlign: TextAlign.center,
                                  style: AppText.display(size: 22),
                                ),
                                const SizedBox(height: 10),
                                Text.rich(
                                  TextSpan(
                                    text: "Ce produit fait partie de l'offre : ",
                                    style: AppText.body(
                                      size: 14.5,
                                      color: AppColors.textMuted,
                                      height: 1.35,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: gift.title,
                                        style: AppText.body(
                                          size: 14.5,
                                          weight: FontWeight.w700,
                                          height: 1.35,
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
                                      color: AppColors.amberTint,
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.md,
                                      ),
                                      border: Border.all(
                                        color: AppColors.amber.withValues(
                                          alpha: 0.4,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.card_giftcard_rounded,
                                          size: 22,
                                          color: AppColors.amberDeep,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            gift.description,
                                            style: AppText.body(
                                              size: 13.5,
                                              weight: FontWeight.w600,
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                _PillAction(
                                  label: "Ajouter d'autres produits éligibles",
                                  icon: Icons.add_shopping_cart_rounded,
                                  onTap: () async {
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
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _PillAction.quiet(
                                        label: "Continuer sans cadeau",
                                        onTap: () =>
                                            Navigator.pop(context, false),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _PillAction(
                                        label: "Ajuster à $targetQty",
                                        icon: Icons.add_rounded,
                                        gradient: AppGradients.amber,
                                        glowColor: AppColors.amber,
                                        foreground: AppColors.ink,
                                        onTap: () =>
                                            Navigator.pop(context, true),
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
                      top: 8,
                      right: 8,
                      child: _DialogCloseButton(
                        onDark: gift.imageUrl.isNotEmpty,
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
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
            borderRadius: BorderRadius.circular(AppRadii.xl),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: _DialogPane(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BlisterIcon(
                    icon: Icons.card_giftcard_rounded,
                    tone: Tone.amber,
                    size: 76,
                  ),
                  const SizedBox(height: 22),
                  Text(
                    l10n.giftAvailableTitle,
                    textAlign: TextAlign.center,
                    style: AppText.display(size: 22),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.giftAvailableMessage,
                    textAlign: TextAlign.center,
                    style: AppText.body(size: 15, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      Expanded(
                        child: _PillAction.quiet(
                          label: l10n.noThanks,
                          onTap: () => Navigator.pop(context, false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PillAction(
                          label: l10n.yesOffer,
                          icon: Icons.card_giftcard_rounded,
                          gradient: AppGradients.amber,
                          glowColor: AppColors.amber,
                          foreground: AppColors.ink,
                          onTap: () => Navigator.pop(context, true),
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
      // The sale is saved and its points are earned.
      celebrate(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.saleSuccessMessage),
          backgroundColor: AppColors.mintDeep,
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
                borderRadius: BorderRadius.circular(AppRadii.xl),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: _DialogPane(
                child: Padding(
                  padding: const EdgeInsets.all(22.0),
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const TintIcon(
                                icon: Icons.card_giftcard_rounded,
                                tone: Tone.amber,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  l10n.offerGift,
                                  style: AppText.display(size: 21),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),

                          Text(
                            l10n.selectGift,
                            style: AppText.label(size: 13.5, letterSpacing: 0),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<Map<String, dynamic>>(
                            initialValue: selectedGiftData,
                            isExpanded: true,
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.amberDeep,
                            ),
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
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
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.body(
                                    size: 14,
                                    weight: FontWeight.w500,
                                  ),
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
                            style: AppText.label(size: 13.5, letterSpacing: 0),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: quantityController,
                            readOnly: true,
                            keyboardType: TextInputType.number,
                            style: AppText.display(size: 18),
                            decoration: InputDecoration(
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
                            style: AppText.label(size: 13.5, letterSpacing: 0),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            decoration: InputDecoration(
                              hintText: l10n.lastName,
                              prefixIcon: const Icon(
                                Icons.person_outline_rounded,
                                size: 20,
                              ),
                            ),
                            onSaved: (value) => nomClient = value,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            decoration: InputDecoration(
                              hintText: l10n.firstName,
                              prefixIcon: const Icon(
                                Icons.person_outline_rounded,
                                size: 20,
                              ),
                            ),
                            onSaved: (value) => prenomClient = value,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              hintText: l10n.phone,
                              prefixIcon: const Icon(
                                Icons.phone_rounded,
                                size: 20,
                              ),
                            ),
                            onSaved: (value) => phoneNumber = value,
                          ),
                          const SizedBox(height: 26),

                          Row(
                            children: [
                              Expanded(
                                child: _PillAction.quiet(
                                  label: l10n.cancel,
                                  onTap: () => Navigator.pop(context),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _PillAction(
                                  label: l10n.confirm,
                                  gradient: AppGradients.amber,
                                  glowColor: AppColors.amber,
                                  foreground: AppColors.ink,
                                  onTap: () async {
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
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
            backgroundColor: AppColors.mintDeep,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorOccurred(e.toString())),
            backgroundColor: AppColors.coralDeep,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Read without subscribing: this build must not re-run when a dialog
    // opens over the page, or the goal cards below would reload.
    final canPop = Navigator.of(context).canPop();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: AppBackground(
          accent: Tone.peach,
          child: Stack(
            children: [
              Positioned.fill(
                child: FutureBuilder<_ProductScreenData>(
                  future: _dataFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SafeArea(
                        bottom: false,
                        child: SingleChildScrollView(
                          physics: NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                          child: Shimmer(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SkeletonBox(height: 310, radius: AppRadii.xl),
                                SizedBox(height: 22),
                                SkeletonBox(width: 240, height: 26),
                                SizedBox(height: 12),
                                SkeletonBox(
                                  width: 96,
                                  height: 28,
                                  radius: AppRadii.pill,
                                ),
                                SizedBox(height: 24),
                                SkeletonBox(height: 170, radius: AppRadii.lg),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    if (snapshot.hasError || !snapshot.hasData) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'Error: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: AppText.body(color: AppColors.textMuted),
                          ),
                        ),
                      );
                    }

                    final data = snapshot.data!;
                    final product = data.product;
                    final user = data.user;
                    final pharmacy = data.pharmacy;

                    if (product == null) {
                      return const EmptyState(
                        icon: Icons.search_off_rounded,
                        tone: Tone.peach,
                        title: 'Product not found.',
                      );
                    }
                    if (user == null || pharmacy == null) {
                      if (user?.role == 'Dermo-conseiller' &&
                          pharmacy == null) {
                        return EmptyState(
                          icon: Icons.pin_drop_rounded,
                          tone: Tone.coral,
                          title: "Check-in Requis",
                          message:
                              "Vous devez effectuer un check-in dans une pharmacie avant de pouvoir enregistrer une vente ou consulter un produit.",
                          actionLabel: "Aller au Tableau de Bord",
                          onAction: () {
                            Navigator.of(
                              context,
                            ).pushReplacementNamed('/dashboard_home');
                          },
                        );
                      }
                      return const EmptyState(
                        icon: Icons.person_off_rounded,
                        tone: Tone.coral,
                        title: 'Could not load user profile.',
                      );
                    }

                    // Check if product is disabled
                    if (product.isDisabled) {
                      return _buildDisabledProductView(l10n, product);
                    }

                    final relatedGoals = _goalService.findMatchingGoals(
                      product,
                      data.allGoals,
                    );

                    // Built once here and handed to the scroll view below, so
                    // an inset change (keyboard, rotation) re-pads the page
                    // without rebuilding its sections.
                    final content = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Product Image and Basic Info
                        Entrance(
                          scaleFrom: 0.97,
                          child: _buildProductHeader(product),
                        ),
                        const SizedBox(height: 20),

                        // Sale Details Card (Quantity & Price)
                        Entrance(
                          delay: const Duration(milliseconds: 100),
                          child: _buildModernSaleCard(
                            l10n,
                            product,
                            pharmacy.clientCategory,
                            data.challenges,
                            userRole: user.role,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Description
                        if (product.description.isNotEmpty) ...[
                          _buildModernSection(
                            l10n.description,
                            Icons.article_rounded,
                            product.description,
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Usage Tips (Conseil d'utilisation)
                        if (product.protocol.isNotEmpty) ...[
                          _buildModernSection(
                            l10n.usageTips,
                            Icons.lightbulb_rounded,
                            product.protocol,
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Protocol (Recommendé avec)
                        if (data.recommendedProducts.isNotEmpty) ...[
                          _buildModernSectionTitle(
                            l10n.protocol,
                            Icons.local_hospital_rounded,
                          ),
                          _buildRecommendedProductsList(
                            data.recommendedProducts,
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Composition
                        if (product.composition.isNotEmpty) ...[
                          _buildModernSection(
                            l10n.composition,
                            Icons.science_rounded,
                            product.composition,
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Related Goals (Objectifs associés)
                        if (relatedGoals.isNotEmpty) ...[
                          _buildModernSectionTitle(
                            l10n.relatedGoals,
                            Icons.flag_rounded,
                          ),
                          ...relatedGoals.map(
                            (goal) => _buildModernGoalCard(
                              goal,
                              product,
                              user,
                              pharmacy,
                            ),
                          ),
                        ],
                      ],
                    );

                    // A scaffold of its own, so the page scrolls underneath
                    // the frosted action bar.
                    return Scaffold(
                      backgroundColor: Colors.transparent,
                      extendBody: true,
                      body: Builder(
                        builder: (context) {
                          final insets = MediaQuery.paddingOf(context);
                          return SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              20,
                              insets.top + 8,
                              20,
                              insets.bottom + 24,
                            ),
                            child: content,
                          );
                        },
                      ),
                      bottomNavigationBar: _buildModernActionBar(
                        l10n,
                        product,
                        user,
                        pharmacy.clientCategory,
                        data.challenges,
                      ),
                    );
                  },
                ),
              ),

              // Floating glass controls: back on the left, the hotline on
              // the right. They stay put while the page scrolls.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(29, 17, 29, 0),
                    child: Row(
                      children: [
                        if (canPop)
                          Builder(
                            builder: (context) => _GlassCircleButton(
                              icon: Icons.arrow_back_rounded,
                              tooltip: MaterialLocalizations.of(
                                context,
                              ).backButtonTooltip,
                              onTap: () => Navigator.maybePop(context),
                            ),
                          ),
                        const Spacer(),
                        _GlassCircleButton(
                          icon: Icons.phone_in_talk_rounded,
                          tooltip: l10n.phone,
                          onTap: () async {
                            final Uri telLaunchUri = Uri(scheme: 'tel', path: '+21698667540');
                            if (await canLaunchUrl(telLaunchUri)) {
                              await launchUrl(telLaunchUri);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductHeader(Product product) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The stage: the product, lit on a pane of peach-tinted glass.
        Glass(
          tint: Color.lerp(AppColors.peachTint, Colors.white, 0.2),
          borderRadius: BorderRadius.circular(AppRadii.xl),
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The floating back and call buttons sit over this row.
              SizedBox(
                height: 64,
                child: Center(
                  child: Text(
                    l10n.scannedProduct,
                    style: AppText.label(
                      size: 14.5,
                      weight: FontWeight.w700,
                      color: AppColors.text,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
              if (product.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  child: Container(
                    color: AppColors.surface,
                    padding: const EdgeInsets.all(14),
                    child: AppNetworkImage(
                      imageUrl: product.imageUrl,
                      height: 208,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      memCacheWidth: 800,
                      memCacheHeight: 800,
                      errorIcon: Icons.image_not_supported_outlined,
                      errorIconSize: 80,
                      errorIconColor: AppColors.lineStrong,
                      backgroundColor: AppColors.surface,
                      placeholder: (context, url) => const SizedBox(
                        height: 208,
                        child: Center(child: CapsuleLoader(size: 38)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            product.name,
            style: AppText.display(size: 25, height: 1.14),
          ),
        ),
        if (product.marque.isNotEmpty) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TonePill(label: product.marque),
          ),
        ],
      ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SoftCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              // Quantity Selector
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.quantity,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(size: 16, weight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ValueListenableBuilder<int>(
                    valueListenable: _quantityNotifier,
                    builder: (context, quantity, child) {
                      return Glass(
                        shadow: false,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        padding: const EdgeInsets.all(5),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _RoundStepButton(
                              icon: Icons.remove_rounded,
                              semanticLabel: '-',
                              size: 50,
                              tone: Tone.peach,
                              enabled: quantity > 1,
                              onTap: () {
                                if (quantity > 1) _quantityNotifier.value--;
                              },
                            ),
                            ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 58),
                              child: AnimatedSwitcher(
                                duration: AppMotion.fast,
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                      opacity: animation,
                                      child: ScaleTransition(
                                        scale: Tween(
                                          begin: 0.8,
                                          end: 1.0,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    ),
                                child: Text(
                                  '$quantity',
                                  key: ValueKey(quantity),
                                  textAlign: TextAlign.center,
                                  style: AppText.display(size: 28),
                                ),
                              ),
                            ),
                            _RoundStepButton(
                              icon: Icons.add_rounded,
                              semanticLabel: '+',
                              size: 50,
                              tone: Tone.peach,
                              filled: true,
                              onTap: () {
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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.ink.withValues(alpha: 0.07),
                ),
              ),
              // Points Display
              Row(
                children: [
                  const TintIcon(
                    icon: Icons.stars_rounded,
                    tone: Tone.mint,
                    size: 42,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Points',
                    style: AppText.body(size: 16, weight: FontWeight.w700),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ValueListenableBuilder<int>(
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

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // What this sale earns: rolls as the quantity
                            // changes.
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: CountUp(
                                value: pointsEarned,
                                duration: AppMotion.medium,
                                style: AppText.display(
                                  size: 42,
                                  color: AppColors.mintDeep,
                                ),
                              ),
                            ),
                            if (currentChallenge != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: TonePill(
                                    label:
                                        "($pointsPerUnit pts/u vs Standard: $standardPoints)",
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Optional: Matching Challenge Badge
        if (activeChallenge != null) ...[
          const SizedBox(height: 12),
          SoftCard(
            tint: AppColors.indigoTint,
            radius: AppRadii.md + 2,
            shadow: false,
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            child: Row(
              children: [
                const BlisterIcon(
                  icon: Icons.celebration_rounded,
                  size: 40,
                  glow: false,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Challenge: ${activeChallenge.title}",
                    style: AppText.body(
                      size: 14.5,
                      weight: FontWeight.w700,
                      color: AppColors.indigoDeep,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildModernSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 12),
      child: Row(
        children: [
          TintIcon(icon: icon, tone: Tone.peach, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: AppText.display(size: 19),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSection(String title, IconData icon, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 12),
          child: Row(
            children: [
              TintIcon(icon: icon, tone: Tone.peach, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: AppText.display(size: 19),
                ),
              ),
            ],
          ),
        ),
        SoftCard(
          radius: AppRadii.md + 2,
          shadow: false,
          padding: const EdgeInsets.all(18),
          child: Text(
            content,
            style: AppText.body(size: 15, height: 1.6),
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendedProductsList(List<Product> products) {
    return SizedBox(
      height: 232,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        // Let cards slide out through the page gutter instead of being cut.
        clipBehavior: Clip.none,
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: SizedBox(
              width: 172,
              child: SoftCard(
                radius: AppRadii.md + 2,
                shadow: false,
                padding: const EdgeInsets.all(8),
                semanticLabel: product.name,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductScreen(id: product.id),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      child: Container(
                        height: 132,
                        width: double.infinity,
                        color: AppColors.surface,
                        child: AppNetworkImage(
                          imageUrl: product.imageUrl,
                          height: 132,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          memCacheWidth: 400,
                          memCacheHeight: 400,
                          errorIcon: Icons.image_not_supported_outlined,
                          errorIconSize: 40,
                          errorIconColor: AppColors.lineStrong,
                          backgroundColor: AppColors.surface,
                          placeholder: (context, url) =>
                              const SkeletonBox(height: 132, radius: 0),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(6, 10, 6, 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: AppText.body(
                                size: 14,
                                weight: FontWeight.w700,
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              product.marque,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.label(
                                size: 12.5,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
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
        final tone = isEligible ? Tone.mint : Tone.coral;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SoftCard(
            radius: AppRadii.md + 2,
            shadow: false,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                TintIcon(
                  icon: isEligible
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  tone: tone,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        style: AppText.body(
                          size: 15.5,
                          weight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TonePill(
                        label: isEligible ? "Eligible" : "Not eligible",
                        tone: tone,
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
  }

  Widget _buildModernActionBar(
    AppLocalizations l10n,
    Product product,
    UserModel user,
    String? pharmacyCategory,
    List<Challenge> challenges,
  ) {
    return GlassBottomBar(
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
                      style: AppText.label(size: 12.5, letterSpacing: 0),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${product.price.toStringAsFixed(3)} TND',
                      style: AppText.display(size: 26),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12), // Space between price and button
          // Button row at the bottom, centered
          if (user != null && user.role == 'Dermo-conseiller' && !widget.isSelectionMode && widget.sale == null) ...[
            // Option B: Ajouter au panier (nouvelle methode panier)
            PrimaryButton(
              label: "Ajouter au panier",
              icon: Icons.add_shopping_cart_rounded,
              onPressed: () async {
                final basketProvider = Provider.of<BasketProvider>(context, listen: false);
                final int quantity = _quantityNotifier.value;
                final double unitPoints = _getEffectivePoints(
                  product,
                  challenges,
                  pharmacyCategory,
                  userRole: user.role,
                );
                final success = await basketProvider.addProduct(
                  product: product,
                  quantity: quantity,
                  pointsEarned: unitPoints * quantity,
                );
                if (success && context.mounted) {
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.hideCurrentSnackBar();
                  final controller = messenger.showSnackBar(
                    SnackBar(
                      content: Text("${product.name} (x$quantity) ajouté au panier !"),
                      backgroundColor: AppColors.mintDeep,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 5),
                      showCloseIcon: true,
                      action: SnackBarAction(
                        label: "Voir le panier",
                        textColor: Colors.white,
                        onPressed: () {
                          messenger.hideCurrentSnackBar();
                          Navigator.pushNamed(context, '/basket');
                        },
                      ),
                    ),
                  );

                  Timer(const Duration(seconds: 5), () {
                    try {
                      controller.close();
                    } catch (_) {}
                  });
                }
              },
            ),
            const SizedBox(height: 10),
            // Option A: Vente directe (ancienne methode sans panier)
            SecondaryButton(
              label: l10n.confirmSale,
              icon: Icons.flash_on_rounded,
              tone: Tone.peach,
              onPressed: () => _submitSale(
                product,
                user,
                pharmacyCategory,
                challenges,
              ),
            ),
          ] else ...[
            PrimaryButton(
              label: widget.isSelectionMode
                  ? "Ajouter à la vente"
                  : (widget.sale != null
                        ? l10n.updateSale
                        : l10n.confirmSale),
              icon: widget.isSelectionMode
                  ? Icons.add_shopping_cart_rounded
                  : Icons.check_circle_outline_rounded,
              // Indigo to add to a sale in progress, peach to confirm one.
              gradient: widget.isSelectionMode
                  ? AppGradients.indigo
                  : Tone.peach.gradient,
              glowColor: widget.isSelectionMode
                  ? AppColors.indigo
                  : AppColors.peach,
              foreground: widget.isSelectionMode
                  ? Colors.white
                  : AppColors.ink,
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
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDisabledProductView(AppLocalizations l10n, Product product) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          // Clears the floating back and call buttons.
          padding: const EdgeInsets.fromLTRB(24, 76, 24, 24),
          child: Entrance(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Product Image
                if (product.imageUrl.isNotEmpty)
                  Glass(
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                    padding: const EdgeInsets.all(10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          // Any colour without saturation greys the photo.
                          Colors.white.withValues(alpha: 0.5),
                          BlendMode.saturation,
                        ),
                        child: CachedNetworkImage(
                          imageUrl: product.imageUrl,
                          height: 200,
                          width: 200,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const SkeletonBox(width: 200, height: 200, radius: 0),
                          errorWidget: (context, url, error) => Container(
                            height: 200,
                            width: 200,
                            color: AppColors.surfaceSunken,
                            child: const Icon(
                              Icons.image_not_supported_rounded,
                              size: 80,
                              color: AppColors.lineStrong,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 28),

                // Disabled Icon
                const BlisterIcon(
                  icon: Icons.block_rounded,
                  tone: Tone.coral,
                  size: 84,
                ),
                const SizedBox(height: 22),

                // Product Name
                Text(
                  product.name,
                  textAlign: TextAlign.center,
                  style: AppText.display(size: 24, height: 1.15),
                ),
                const SizedBox(height: 8),

                // Product Brand
                Text(
                  product.marque,
                  textAlign: TextAlign.center,
                  style: AppText.body(size: 16, color: AppColors.textMuted),
                ),
                const SizedBox(height: 28),

                // Warning Container
                SoftCard(
                  tint: AppColors.coralTint,
                  radius: AppRadii.md + 2,
                  shadow: false,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.coralDeep,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.productNotAvailable,
                              style: AppText.display(
                                size: 18,
                                color: AppColors.coralDeep,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.productNotAvailableMessage,
                        textAlign: TextAlign.center,
                        style: AppText.body(size: 14.5, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Back Button
                PrimaryButton(
                  label: l10n.goBack,
                  icon: Icons.arrow_back_rounded,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private presentation helpers for the sales flow.
// ---------------------------------------------------------------------------

/// The frosted pane every dialog of this screen sits on: glass, with a little
/// extra white so long product lists stay easy to read over the dimmed page.
class _DialogPane extends StatelessWidget {
  final Widget child;
  const _DialogPane({required this.child});

  @override
  Widget build(BuildContext context) {
    return Glass(
      blur: Glass.frost,
      shadow: false,
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: ColoredBox(
        color: Colors.white.withValues(alpha: 0.6),
        child: child,
      ),
    );
  }
}

/// Round close button for dialogs, with a 44pt target.
class _DialogCloseButton extends StatelessWidget {
  final VoidCallback onTap;
  final String? tooltip;
  final bool onDark;

  const _DialogCloseButton({
    required this.onTap,
    this.tooltip,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final label =
        tooltip ?? MaterialLocalizations.of(context).closeButtonTooltip;
    return Tooltip(
      message: label,
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.9,
        semanticLabel: label,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: onDark
                    ? AppColors.ink.withValues(alpha: 0.5)
                    : AppColors.ink.withValues(alpha: 0.07),
                border: onDark
                    ? Border.all(color: Colors.white.withValues(alpha: 0.3))
                    : null,
              ),
              child: Icon(
                Icons.close_rounded,
                size: 20,
                color: onDark ? Colors.white : AppColors.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact pill action for dialogs, where French labels need room to wrap
/// onto a second line. Filled with a gradient by default; [_PillAction.quiet]
/// is a pale glass pill for the way out.
class _PillAction extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Gradient gradient;
  final Color glowColor;
  final Color foreground;
  final bool quiet;

  const _PillAction({
    required this.label,
    this.icon,
    this.onTap,
    this.gradient = AppGradients.indigo,
    this.glowColor = AppColors.indigo,
    this.foreground = Colors.white,
  }) : quiet = false;

  const _PillAction.quiet({required this.label, this.onTap})
    : icon = null,
      gradient = AppGradients.indigo,
      glowColor = AppColors.indigo,
      foreground = AppColors.indigoDeep,
      quiet = true;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: quiet ? null : gradient,
          color: quiet ? Colors.white.withValues(alpha: 0.8) : null,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(
            color: quiet
                ? AppColors.lineStrong
                : Colors.white.withValues(alpha: 0.28),
          ),
          boxShadow: quiet
              ? null
              : AppShadows.glow(glowColor, strength: 0.28),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppText.body(
                  size: 14,
                  weight: FontWeight.w700,
                  color: foreground,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One round half of a quantity stepper.
class _RoundStepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;
  final double size;
  final Tone tone;
  final bool enabled;
  final bool filled;

  const _RoundStepButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.size = 44,
    this.tone = Tone.indigo,
    this.enabled = true,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color fill = !enabled
        ? AppColors.ink.withValues(alpha: 0.05)
        : (filled ? tone.color : tone.tint);
    final Color fg = !enabled
        ? AppColors.textFaint
        : (filled ? AppColors.ink : tone.deep);
    return Pressable(
      onTap: onTap,
      pressedScale: 0.88,
      semanticLabel: semanticLabel,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          boxShadow: filled && enabled
              ? AppShadows.glow(tone.color, strength: 0.3)
              : null,
        ),
        child: Icon(icon, size: size * 0.5, color: fg),
      ),
    );
  }
}

/// A round frosted button for light surfaces. The design system's
/// [GlassIconButton] is drawn for ink; this one floats over the pastel page.
class _GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _GlassCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.9,
        semanticLabel: tooltip,
        child: Glass(
          blur: Glass.frost,
          width: 46,
          height: 46,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: Icon(icon, size: 22, color: AppColors.text),
        ),
      ),
    );
  }
}
