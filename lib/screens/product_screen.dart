import 'dart:async';
import 'package:flutter/material.dart';
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
  final String sku;
  const ProductScreen({super.key, required this.sku});

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
    _dataFuture = _loadData();
  }

  @override
  void dispose() {
    _quantityNotifier.dispose();
    super.dispose();
  }

  Future<_ProductScreenData> _loadData() async {
    final product = await _productService.getProductBySku(widget.sku);
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

  void _confirmSale(Product product, UserModel user) {
    final sale = Sale(
      id: '',
      userId: user.uid,
      pharmacyId: user.pharmacyId,
      productId: product.id,
      productNameSnapshot: product.name,
      quantity: _quantityNotifier.value,
      pointsEarned: product.points * _quantityNotifier.value,
      saleDate: DateTime.now(),
    );
    _saleService.createSale(sale);
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
          if (user == null || pharmacy == null)
            return Center(child: Text('Could not load user profile.'));

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
                      const SizedBox(height: 16),
                      Text(
                        product.description,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF4A5568),
                          height: 1.5,
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
                        ...data.recommendedProducts.map(
                          (p) => _buildRecommendedProductCard(p),
                        ),
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
                l10n.availableStock,
                style: const TextStyle(fontSize: 16, color: Color(0xFF4A5568)),
              ),
              Text(
                l10n.stockAmount(product.stock),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF102132),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
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
                          if (quantity < product.stock)
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
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            const Icon(Icons.link, color: Color(0xFF94A3B8), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                product.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
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
            onPressed: product.stock > 0
                ? () => _confirmSale(product, user)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F9BD1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
            ),
            child: Text(
              product.stock > 0 ? l10n.confirmSale : l10n.outOfStock,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
