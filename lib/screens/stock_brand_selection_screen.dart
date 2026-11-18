import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novopharma/models/product.dart';
import 'package:novopharma/models/stock_models.dart';
import 'package:novopharma/services/product_service.dart';
import 'package:novopharma/screens/brand_stock_input_screen.dart';
import 'package:novopharma/screens/stock_barcode_scanner_screen.dart';
import 'package:novopharma/widgets/expiration_dialog.dart';
import 'package:novopharma/design/design.dart';

class StockBrandSelectionScreen extends StatefulWidget {
  final String pharmacyId;
  final String pharmacyName;

  const StockBrandSelectionScreen({
    super.key,
    required this.pharmacyId,
    required this.pharmacyName,
  });

  @override
  State<StockBrandSelectionScreen> createState() => _StockBrandSelectionScreenState();
}

class _StockBrandSelectionScreenState extends State<StockBrandSelectionScreen> {
  final ProductService _productService = ProductService();
  List<Product> _allProducts = [];
  List<String> _brands = [];
  bool _isLoading = true;
  Map<String, ProductStockItem> _draftProducts = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch all products
      _allProducts = await _productService.getProducts();

      // 2. Extract unique brands
      final Set<String> uniqueBrands = {};
      for (var p in _allProducts) {
        if (p.marque.isNotEmpty) {
          uniqueBrands.add(p.marque.trim());
        }
      }
      _brands = uniqueBrands.toList()..sort();

      // 3. Load SharedPreferences Draft
      final prefs = await SharedPreferences.getInstance();
      final draftKey = 'stock_draft_${widget.pharmacyId}';
      final draftString = prefs.getString(draftKey);

      if (draftString != null) {
        final Map<String, dynamic> draftMap = json.decode(draftString);
        final Map<String, dynamic> productsMap = draftMap['products'] ?? {};
        
        _draftProducts = productsMap.map((key, value) {
          return MapEntry(key, ProductStockItem.fromJson(value));
        });
      }
    } catch (e) {
      debugPrint("Error loading products/draft: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draftKey = 'stock_draft_${widget.pharmacyId}';

    final draftMap = {
      'pharmacyId': widget.pharmacyId,
      'pharmacyName': widget.pharmacyName,
      'lastUpdatedAt': DateTime.now().toIso8601String(),
      'products': _draftProducts.map((key, value) => MapEntry(key, value.toJson())),
    };

    await prefs.setString(draftKey, json.encode(draftMap));
  }

  Future<void> _scanSKU() async {
    final String? scannedSku = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const StockBarcodeScannerScreen()),
    );

    if (scannedSku == null || scannedSku.isEmpty) return;

    // Search product list for the SKU
    final matchedProduct = _allProducts.firstWhere(
      (p) => p.sku.toLowerCase() == scannedSku.trim().toLowerCase(),
      orElse: () => Product(
        id: '',
        name: '',
        marque: '',
        category: '',
        description: '',
        price: 0,
        points: 0,
        pointsPharmacie: 0,
        pointsParaPharmacie: 0,
        pointsDermoConseiller: 0,
        pointsUnified: true,
        sku: '',
        stock: 0,
        protocol: '',
        recommendedWith: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        imageUrl: '',
        composition: '',
        clientCode: 0,
      ),
    );

    if (matchedProduct.id.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Aucun produit trouvé avec le SKU: $scannedSku"),
            backgroundColor: AppColors.coralDeep,
          ),
        );
      }
      return;
    }

    if (mounted) {
      final initialItem = _draftProducts[matchedProduct.id];
      showDialog(
        context: context,
        builder: (context) => ExpirationDialog(
          product: matchedProduct,
          initialStockItem: initialItem,
          onSave: (updatedItem) {
            setState(() {
              if (updatedItem != null) {
                _draftProducts[matchedProduct.id] = updatedItem;
              } else {
                _draftProducts.remove(matchedProduct.id);
              }
            });
            _saveDraft();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Stock mis à jour pour: ${matchedProduct.name}")),
            );
          },
        ),
      );
    }
  }

  void _onBrandSelected(String brand) async {
    // Navigate to BrandStockInputScreen
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BrandStockInputScreen(
          pharmacyId: widget.pharmacyId,
          pharmacyName: widget.pharmacyName,
          brand: brand,
        ),
      ),
    );

    // Refresh draft data when returning
    _loadData();
  }

  // Presentation only: the first screenful of rows arrives once per visit.
  // Rows built later (scrolling back up, returning from a brand) appear in
  // place.
  bool _rowsArrived = false;

  Widget _arrive(int index, Widget child) {
    if (index >= 8) return child;
    final play = !_rowsArrived;
    if (play) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _rowsArrived = true);
    }
    return Entrance(
      delay: play ? Duration(milliseconds: 50 * index) : Duration.zero,
      duration: play ? AppMotion.slow : Duration.zero,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final int totalTracked = _draftProducts.values.fold<int>(0, (sum, item) => sum + (item.totalQuantity ?? 0));
    final int distinctItems = _draftProducts.keys.length;
    final int priceOnlyCount = _draftProducts.values.where((item) => item.isPriceOnly || item.totalQuantity == null).length;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: InkAppBar(
        title: "Audit Stock - Marques",
        subtitle: widget.pharmacyName,
        leading: GlassIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onTap: () => Navigator.pop(context),
        ),
      ),
      body: AppBackground(
        child: _isLoading
            ? const SkeletonList(
                count: 6,
                itemHeight: 72,
                padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
              )
            : Column(
                children: [
                  // Info Banner
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                    child: Entrance(
                      child: SoftCard(
                        padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                        radius: 24,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Sélectionnez une marque pour saisir l'inventaire",
                                style: AppText.body(
                                  size: 14,
                                  color: AppColors.textMuted,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.indigoTint,
                                borderRadius: BorderRadius.circular(AppRadii.sm),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "$distinctItems prod.",
                                    style: AppText.display(size: 18, color: AppColors.indigoDeep),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    priceOnlyCount > 0 && totalTracked == 0
                                        ? "$priceOnlyCount prix"
                                        : (priceOnlyCount > 0 ? "$totalTracked Q (${priceOnlyCount}P)" : "Total: $totalTracked Q"),
                                    style: AppText.label(size: 12, color: AppColors.indigoDeep, letterSpacing: 0),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Brands List
                  Expanded(
                    child: _brands.isEmpty
                        ? const EmptyState(
                            icon: Icons.inventory_2_outlined,
                            title: "Aucune marque disponible",
                          )
                        : ListView.builder(
                            // Room for the floating scan button.
                            padding: EdgeInsets.fromLTRB(
                              20,
                              8,
                              20,
                              MediaQuery.paddingOf(context).bottom + 96,
                            ),
                            itemCount: _brands.length,
                            itemBuilder: (context, index) {
                              final brand = _brands[index];

                              // Calculate how many products of this brand are in draft
                              final brandProducts = _allProducts.where((p) => p.marque == brand).map((p) => p.id);
                              final brandDraftCount = _draftProducts.keys.where((id) => brandProducts.contains(id)).length;
                              final hasEntries = brandDraftCount > 0;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _arrive(
                                  index,
                                  SoftCard(
                                    onTap: () => _onBrandSelected(brand),
                                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                                    radius: 24,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: hasEntries ? AppColors.mintTint : AppColors.indigoTint,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            brand.isNotEmpty ? brand[0].toUpperCase() : 'B',
                                            style: AppText.display(
                                              size: 19,
                                              color: hasEntries ? AppColors.mintDeep : AppColors.indigoDeep,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                brand,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppText.body(size: 16, weight: FontWeight.w700, height: 1.2),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                hasEntries ? "$brandDraftCount produit(s) saisi(s)" : "Aucune saisie",
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppText.label(
                                                  size: 13,
                                                  color: hasEntries ? AppColors.mintDeep : AppColors.textMuted,
                                                  letterSpacing: 0,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        hasEntries
                                            ? const Icon(Icons.check_circle_rounded, color: AppColors.mint, size: 26)
                                            : const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint, size: 24),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
      floatingActionButton: PrimaryButton.mint(
        label: "Scanner SKU",
        icon: Icons.qr_code_scanner_rounded,
        onPressed: _scanSKU,
        expand: false,
      ),
    );
  }
}
