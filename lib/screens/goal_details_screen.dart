import 'package:flutter/material.dart';
import 'package:novopharma/models/goal.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';
import 'package:novopharma/services/product_service.dart';
import 'package:novopharma/services/pharmacy_service.dart';
import '../theme.dart';

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
      backgroundColor: LightModeColors.lightBackground,
      appBar: AppBar(
        title: Text(
          l10n.goalDetails,
          style: const TextStyle(
            color: LightModeColors.lightPrimaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: LightModeColors.lightPrimary,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: LightModeColors.lightPrimaryContainer,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.goal.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: LightModeColors.dashboardTextPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Text(
              widget.goal.description,
              style: const TextStyle(
                fontSize: 16,
                color: LightModeColors.dashboardTextSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            const Divider(color: LightModeColors.lightOutline),
            const SizedBox(height: 20),
            Text(
              l10n.eligibilityCriteria,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: LightModeColors.dashboardTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
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
        color: LightModeColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: LightModeColors.lightOnSurface.withAlpha(15),
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
              Icon(icon, color: LightModeColors.warning, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: LightModeColors.dashboardTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: items
                      .map(
                        (item) => Chip(
                          label: Text(item, overflow: TextOverflow.ellipsis),
                          backgroundColor: LightModeColors.warning.withValues(
                            alpha: 0.1,
                          ),
                          labelStyle: const TextStyle(
                            color: LightModeColors.warning,
                            fontWeight: FontWeight.w500,
                          ),
                          side: BorderSide.none,
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
