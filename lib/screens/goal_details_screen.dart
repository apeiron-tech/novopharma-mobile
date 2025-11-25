import 'package:flutter/material.dart';
import 'package:novopharma/models/goal.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';
import 'package:novopharma/services/product_service.dart';
import 'package:novopharma/services/pharmacy_service.dart';

class GoalDetailsScreen extends StatefulWidget {
  final Goal goal;

  const GoalDetailsScreen({super.key, required this.goal});

  @override
  State<GoalDetailsScreen> createState() => _GoalDetailsScreenState();
}

class _GoalDetailsScreenState extends State<GoalDetailsScreen> {
  final ProductService _productService = ProductService();
  final PharmacyService _pharmacyService = PharmacyService();

  Future<List<String>>? _productNamesFuture;
  Future<List<String>>? _pharmacyNamesFuture;

  @override
  void initState() {
    super.initState();
    _fetchCriteriaNames();
  }

  void _fetchCriteriaNames() {
    final criteria = widget.goal.criteria;
    if (criteria.products.isNotEmpty) {
      _productNamesFuture = _productService
          .getProductsByIds(criteria.products)
          .then((products) => products.map((p) => p.name).toList());
    }
    if (criteria.pharmacyIds.isNotEmpty) {
      _pharmacyNamesFuture = _pharmacyService
          .getPharmaciesByIds(criteria.pharmacyIds)
          .then((pharmacies) => pharmacies.map((p) => p.name).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: Text(
          l10n.goalDetails,
          style: const TextStyle(
            color: Color(0xFF102132),
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF102132)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.goal.title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF102132),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.goal.description,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF4A5568),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 24),
            Text(
              l10n.eligibilityCriteria,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF102132),
              ),
            ),
            const SizedBox(height: 16),
            _buildCriteriaSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCriteriaSection(BuildContext context) {
    final criteria = widget.goal.criteria;
    final l10n = AppLocalizations.of(context)!;
    final List<Widget> criteriaWidgets = [];

    if (criteria.products.isNotEmpty) {
      criteriaWidgets.add(
        _buildFutureCriteriaCard(
          icon: Icons.inventory_2_outlined,
          title: l10n.eligibleProducts,
          future: _productNamesFuture,
        ),
      );
    }
    if (criteria.pharmacyIds.isNotEmpty) {
      criteriaWidgets.add(
        _buildFutureCriteriaCard(
          icon: Icons.local_pharmacy_outlined,
          title: l10n.eligiblePharmacies,
          future: _pharmacyNamesFuture,
        ),
      );
    }
    if (criteria.brands.isNotEmpty) {
      criteriaWidgets.add(
        _buildCriteriaCard(
          icon: Icons.stars_outlined,
          title: l10n.eligibleBrands,
          items: criteria.brands,
        ),
      );
    }
    if (criteria.categories.isNotEmpty) {
      criteriaWidgets.add(
        _buildCriteriaCard(
          icon: Icons.category_outlined,
          title: l10n.eligibleCategories,
          items: criteria.categories,
        ),
      );
    }
    if (criteria.zones.isNotEmpty) {
      criteriaWidgets.add(
        _buildCriteriaCard(
          icon: Icons.public_outlined,
          title: l10n.eligibleZones,
          items: criteria.zones,
        ),
      );
    }
    if (criteria.clientCategories.isNotEmpty) {
      criteriaWidgets.add(
        _buildCriteriaCard(
          icon: Icons.groups_outlined,
          title: l10n.eligibleClientCategories,
          items: criteria.clientCategories,
        ),
      );
    }

    if (criteriaWidgets.isEmpty) {
      return Text(l10n.noSpecificCriteria);
    }

    return Column(children: criteriaWidgets);
  }

  Widget _buildFutureCriteriaCard({
    required IconData icon,
    required String title,
    required Future<List<String>>? future,
  }) {
    return FutureBuilder<List<String>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildCriteriaCard(
            icon: icon,
            title: title,
            items: [],
            isLoading: true,
          );
        } else if (snapshot.hasError) {
          return _buildCriteriaCard(
            icon: icon,
            title: title,
            items: ['Error loading data'],
          );
        } else if (snapshot.hasData) {
          return _buildCriteriaCard(
            icon: icon,
            title: title,
            items: snapshot.data!,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildCriteriaCard({
    required IconData icon,
    required String title,
    required List<String> items,
    bool isLoading = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF1F9BD1), size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF102132),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: items
                  .map(
                    (item) => Chip(
                      label: Text(item),
                      backgroundColor: const Color(0xFF1F9BD1).withOpacity(0.1),
                      labelStyle: const TextStyle(
                        color: Color(0xFF1F9BD1),
                        fontWeight: FontWeight.w500,
                      ),
                      side: BorderSide.none,
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}
