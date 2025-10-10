import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:novopharma/controllers/sales_history_provider.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/controllers/auth_provider.dart';
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

// Helper class to hold all the data fetched for the screen
class _ProductScreenData {
  final Product? product;
  final List<Product> recommendedProducts;
  final List<Goal> allGoals;
  final UserModel? user;
  final Pharmacy? pharmacy;

  _ProductScreenData({
    this.product,
    this.recommendedProducts = const [],
    this.allGoals = const [],
    this.user,
    this.pharmacy,
  });
}

class ProductScreen extends StatefulWidget {
  final String? sku;
  final Sale? sale;
  const ProductScreen({super.key, this.sku, this.sale});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final ProductService _productService = ProductService();
  final GoalService _goalService = GoalService();
  final UserService _userService = UserService();
  final PharmacyService _pharmacyService = PharmacyService();
  final SaleService _saleService = SaleService();

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
        : await _productService.getProductBySku(widget.sku!);
    if (product == null) return _ProductScreenData(product: null);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.firebaseUser?.uid;
    if (userId == null) return _ProductScreenData(product: product);

    final [recommendedProducts, allGoals, user] = await Future.wait([
      product.recommendedWith.isNotEmpty
          ? _productService.getProductsByIds(product.recommendedWith)
          : Future.value(<Product>[]),
      _goalService.getUserGoals(),
      _userService.getUser(userId),
    ]);

    Pharmacy? pharmacy;
    final userModel = user as UserModel?;
    if (userModel != null && userModel.pharmacyId.isNotEmpty) {
      final pharmacies = await _pharmacyService.getPharmaciesByIds([
        userModel.pharmacyId,
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
    );
  }

  void _submitSale(Product product, UserModel user) {
    final int quantity = _quantityNotifier.value;
    final double totalPrice = product.price * quantity;

    if (widget.sale != null) {
      // Update existing sale
      final updatedSale = Sale(
        id: widget.sale!.id,
        userId: user.uid,
        pharmacyId: user.pharmacyId,
        productId: product.id,
        productNameSnapshot: product.name,
        quantity: quantity,
        pointsEarned: product.points * quantity,
        saleDate: widget.sale!.saleDate, // Keep original sale date
        totalPrice: totalPrice,
      );
      Provider.of<SalesHistoryProvider>(context, listen: false)
          .updateSale(widget.sale!, updatedSale);
    } else {
      // Create new sale
      final newSale = Sale(
        id: '', // Firestore will generate ID
        userId: user.uid,
        pharmacyId: user.pharmacyId,
        productId: product.id,
        productNameSnapshot: product.name,
        quantity: quantity,
        pointsEarned: product.points * quantity,
        saleDate: DateTime.now(),
        totalPrice: totalPrice,
      );
      _saleService.createSale(newSale);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scannedProduct),
        backgroundColor: const Color(0xFFF6F8FB),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF102132)),
      ),
      backgroundColor: const Color(0xFFF6F8FB),
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
            return Center(child: Text('Could not load user profile.'));
          }

          final relatedGoals = _goalService.findMatchingGoals(
            product,
            data.allGoals,
          );

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (product.imageUrl.isNotEmpty)
                        Center(
                          child: CachedNetworkImage(
                            imageUrl: product.imageUrl,
                            height: 200,
                            placeholder: (context, url) =>
                                const Center(child: CircularProgressIndicator()),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.error),
                          ),
                        ),
                      const SizedBox(height: 24),
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF102132),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        product.marque,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF4A5568),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSaleDetailsCard(l10n, product),
                      const SizedBox(height: 24),
                      if (product.protocol.isNotEmpty) ...[
                        _buildSectionTitle(l10n.protocol),
                        _buildInfoCard(
                          Icons.article_outlined,
                          product.protocol,
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (relatedGoals.isNotEmpty) ...[
                        _buildSectionTitle(l10n.relatedGoals),
                        ...relatedGoals.map(
                          (goal) => _buildGoalEligibilityCard(
                            goal,
                            product,
                            user,
                            pharmacy,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (data.recommendedProducts.isNotEmpty) ...[
                        _buildSectionTitle(l10n.recommendedWith),
                        SizedBox(
                          height: 220,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: data.recommendedProducts.length,
                            itemBuilder: (context, index) {
                              return _buildRecommendedProductCard(
                                  data.recommendedProducts[index]);
                            },
                          ),
                        ),
                      ],
                      if (product.description.isNotEmpty) ...[
                        _buildSectionTitle(l10n.description),
                        Text(
                          product.description,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF4A5568),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (product.composition.isNotEmpty) ...[
                        _buildSectionTitle(l10n.composition),
                        Text(
                          product.composition,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF4A5568),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ],
                  ),
                ),
              ),
              _buildActionBar(l10n, product, user),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF102132),
        ),
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF102040).withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1F9BD1), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, color: Color(0xFF4A5568)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleDetailsCard(AppLocalizations l10n, Product product) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF102040).withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.quantity,
                style: const TextStyle(fontSize: 16, color: Color(0xFF4A5568)),
              ),
              ValueListenableBuilder<int>(
                valueListenable: _quantityNotifier,
                builder: (context, quantity, child) {
                  return Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () {
                          if (quantity > 1) _quantityNotifier.value--;
                        },
                      ),
                      Text(
                        '$quantity',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () {
                          _quantityNotifier.value++;
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.points,
                style: const TextStyle(fontSize: 16, color: Color(0xFF4A5568)),
              ),
              ValueListenableBuilder<int>(
                valueListenable: _quantityNotifier,
                builder: (context, quantity, child) {
                  final pointsEarned = product.points * quantity;
                  return Text(
                    '$pointsEarned Points',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F9BD1),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalEligibilityCard(
    Goal goal,
    Product product,
    UserModel user,
    Pharmacy pharmacy,
  ) {
    return FutureBuilder<bool>(
      future: _goalService.isUserEligibleForGoal(goal, product, user, pharmacy),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(elevation: 0, color: Colors.transparent);
        }
        final isEligible = snapshot.data ?? false;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isEligible ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isEligible ? Colors.green.shade200 : Colors.red.shade200,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isEligible ? Icons.check_circle_outline : Icons.highlight_off,
                color: isEligible ? Colors.green.shade700 : Colors.red.shade700,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isEligible
                            ? Colors.green.shade900
                            : Colors.red.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEligible
                          ? "You are eligible for this goal"
                          : "You are not eligible for this goal",
                      style: TextStyle(
                        color: isEligible
                            ? Colors.green.shade800
                            : Colors.red.shade800,
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

  Widget _buildRecommendedProductCard(Product product) {
    return SizedBox(
      width: 160,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductScreen(sku: product.sku),
            ),
          );
        },
        child: Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(right: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: CachedNetworkImage(
                    imageUrl: product.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.marque,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionBar(
    AppLocalizations l10n,
    Product product,
    UserModel user,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ValueListenableBuilder<int>(
            valueListenable: _quantityNotifier,
            builder: (context, quantity, child) {
              final totalPrice = product.price * quantity;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.totalPrice,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4A5568),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${totalPrice.toStringAsFixed(2)} TND',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF102132),
                    ),
                  ),
                ],
              );
            },
          ),
          ElevatedButton(
            onPressed: () => _submitSale(product, user),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F9BD1),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
            ),
            child: Text(
              widget.sale != null ? l10n.updateSale : l10n.confirmSale,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
