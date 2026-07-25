import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novopharma/models/product.dart';
import 'package:novopharma/models/stock_models.dart';
import 'package:novopharma/services/product_service.dart';
import 'package:novopharma/screens/brand_stock_input_screen.dart';
import 'package:novopharma/screens/stock_barcode_scanner_screen.dart';
import 'package:novopharma/widgets/expiration_dialog.dart';
import 'package:novopharma/theme.dart';

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
            backgroundColor: LightModeColors.lightError,
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

  @override
  Widget build(BuildContext context) {
    int totalTracked = _draftProducts.values.fold(0, (sum, item) => sum + item.totalQuantity);
    int distinctItems = _draftProducts.keys.length;

    return Scaffold(
      backgroundColor: LightModeColors.novoPharmaLightGray,
      appBar: AppBar(
        title: const Text("Audit Stock - Marques", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: LightModeColors.dashboardTextPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 16),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Info Banner
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.pharmacyName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: LightModeColors.dashboardTextPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            const Text("Sélectionnez une marque pour saisir l'inventaire", style: TextStyle(fontSize: 12, color: LightModeColors.novoPharmaGray)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: LightModeColors.novoPharmaLightBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              "$distinctItems prod.",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: LightModeColors.novoPharmaBlue),
                            ),
                            Text(
                              "Total: $totalTracked Q",
                              style: const TextStyle(fontSize: 11, color: LightModeColors.novoPharmaBlue, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                // Brands List
                Expanded(
                  child: _brands.isEmpty
                      ? const Center(child: Text("Aucune marque disponible", style: TextStyle(color: LightModeColors.novoPharmaGray)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          itemCount: _brands.length,
                          itemBuilder: (context, index) {
                            final brand = _brands[index];
                            
                            // Calculate how many products of this brand are in draft
                            final brandProducts = _allProducts.where((p) => p.marque == brand).map((p) => p.id);
                            final brandDraftCount = _draftProducts.keys.where((id) => brandProducts.contains(id)).length;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: LightModeColors.lightOutlineVariant),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 8, offset: const Offset(0, 4)),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                leading: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: LightModeColors.novoPharmaLightGray,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    brand.isNotEmpty ? brand[0].toUpperCase() : 'B',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: LightModeColors.novoPharmaBlue, fontSize: 16),
                                  ),
                                ),
                                title: Text(
                                  brand,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: LightModeColors.dashboardTextPrimary),
                                ),
                                subtitle: brandDraftCount > 0
                                    ? Container(
                                        margin: const EdgeInsets.only(top: 6),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.check_circle, color: LightModeColors.success, size: 14),
                                            const SizedBox(width: 4),
                                            Text(
                                              "$brandDraftCount produit(s) saisi(s)",
                                              style: const TextStyle(fontSize: 12, color: LightModeColors.success, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      )
                                    : const Text("Aucune saisie", style: TextStyle(fontSize: 12, color: LightModeColors.novoPharmaGray)),
                                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: LightModeColors.novoPharmaGray),
                                onTap: () => _onBrandSelected(brand),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scanSKU,
        backgroundColor: LightModeColors.novoPharmaBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text("Scanner SKU", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
