import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novopharma/models/product.dart';
import 'package:novopharma/models/stock_models.dart';
import 'package:novopharma/services/product_service.dart';
import 'package:novopharma/widgets/expiration_dialog.dart';
import 'package:novopharma/theme.dart';

class BrandStockInputScreen extends StatefulWidget {
  final String pharmacyId;
  final String pharmacyName;
  final String brand;

  const BrandStockInputScreen({
    super.key,
    required this.pharmacyId,
    required this.pharmacyName,
    required this.brand,
  });

  @override
  State<BrandStockInputScreen> createState() => _BrandStockInputScreenState();
}

class _BrandStockInputScreenState extends State<BrandStockInputScreen> {
  final ProductService _productService = ProductService();
  List<Product> _brandProducts = [];
  bool _isLoading = true;
  
  // Map of productId -> ProductStockItem
  Map<String, ProductStockItem> _draftProducts = {};
  
  // Map of productId -> TextEditingController for the quantity fields
  final Map<String, TextEditingController> _controllers = {};

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch all products
      final allProducts = await _productService.getProducts();
      
      // 2. Filter by brand
      _brandProducts = allProducts.where((p) => p.marque == widget.brand).toList();

      // 3. Load draft
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

      // Initialize text controllers
      for (var product in _brandProducts) {
        final hasDraft = _draftProducts.containsKey(product.id);
        final initialQty = _draftProducts[product.id]?.totalQuantity ?? 0;
        _controllers[product.id] = TextEditingController(
          text: hasDraft ? initialQty.toString() : '',
        );
      }
    } catch (e) {
      debugPrint("Error loading brand products/draft: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProgress() async {
    // Save entire draft back to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final draftKey = 'stock_draft_${widget.pharmacyId}';

    final draftMap = {
      'pharmacyId': widget.pharmacyId,
      'pharmacyName': widget.pharmacyName,
      'lastUpdatedAt': DateTime.now().toIso8601String(),
      'products': _draftProducts.map((key, value) => MapEntry(key, value.toJson())),
    };

    await prefs.setString(draftKey, json.encode(draftMap));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Progrès sauvegardé localement")),
      );
      Navigator.pop(context);
    }
  }

  void _openExpirationDialog(Product product) {
    final currentItem = _draftProducts[product.id];
    showDialog(
      context: context,
      builder: (context) => ExpirationDialog(
        product: product,
        initialStockItem: currentItem,
        onSave: (updatedItem) {
          setState(() {
            if (updatedItem != null) {
              _draftProducts[product.id] = updatedItem;
              _controllers[product.id]?.text = updatedItem.totalQuantity.toString();
            } else {
              _draftProducts.remove(product.id);
              _controllers[product.id]?.text = '';
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightModeColors.novoPharmaLightGray,
      appBar: AppBar(
        title: Text(widget.brand, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: LightModeColors.dashboardTextPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 16),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProgress,
            child: const Text(
              "Enregistrer",
              style: TextStyle(fontWeight: FontWeight.bold, color: LightModeColors.novoPharmaBlue, fontSize: 15),
            ),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Info Banner
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.pharmacyName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: LightModeColors.dashboardTextPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Saisissez la quantité totale ou ajoutez des lots avec dates d'expiration.",
                        style: TextStyle(fontSize: 12, color: LightModeColors.novoPharmaGray),
                      ),
                    ],
                  ),
                ),
                
                // Search bar
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: LightModeColors.novoPharmaLightGray,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: "Rechercher par nom ou SKU...",
                        hintStyle: const TextStyle(color: LightModeColors.novoPharmaGray, fontSize: 13, fontWeight: FontWeight.normal),
                        prefixIcon: const Icon(Icons.search, color: LightModeColors.novoPharmaBlue, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: LightModeColors.novoPharmaGray, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Products List
                Expanded(
                  child: () {
                    final filteredProducts = _brandProducts.where((product) {
                      final query = _searchQuery.toLowerCase().trim();
                      return product.name.toLowerCase().contains(query) ||
                          product.sku.toLowerCase().contains(query);
                    }).toList();

                    return filteredProducts.isEmpty
                        ? const Center(child: Text("Aucun produit trouvé", style: TextStyle(color: LightModeColors.novoPharmaGray)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            itemCount: filteredProducts.length,
                            itemBuilder: (context, index) {
                              final product = filteredProducts[index];
                              final draftItem = _draftProducts[product.id];
                              final hasExpirations = draftItem?.expirations.isNotEmpty ?? false;

                              final hasQty = draftItem != null;

                              return GestureDetector(
                                onTap: () => _openExpirationDialog(product),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: hasQty ? const Color(0xFFF7F8FF) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: hasQty 
                                        ? LightModeColors.novoPharmaBlue 
                                        : LightModeColors.lightOutlineVariant,
                                    width: hasQty ? 1.5 : 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 8, offset: const Offset(0, 4)),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Product Image
                                        Container(
                                          width: 60,
                                          height: 60,
                                          margin: const EdgeInsets.only(right: 12),
                                          decoration: BoxDecoration(
                                            color: LightModeColors.novoPharmaLightGray,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: LightModeColors.lightOutlineVariant),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: product.imageUrl.isNotEmpty
                                                ? CachedNetworkImage(
                                                    imageUrl: product.imageUrl,
                                                    fit: BoxFit.contain,
                                                    placeholder: (context, url) => const Center(
                                                      child: SizedBox(
                                                        width: 16,
                                                        height: 16,
                                                        child: CircularProgressIndicator(strokeWidth: 2),
                                                      ),
                                                    ),
                                                    errorWidget: (context, url, error) => const Icon(
                                                      Icons.image_not_supported_outlined,
                                                      size: 20,
                                                      color: LightModeColors.novoPharmaGray,
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons.image_not_supported_outlined,
                                                    size: 20,
                                                    color: LightModeColors.novoPharmaGray,
                                                  ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      product.name,
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: LightModeColors.dashboardTextPrimary),
                                                    ),
                                                  ),
                                                  if (hasQty) ...[
                                                    const SizedBox(width: 6),
                                                    const Icon(
                                                      Icons.check_circle_rounded,
                                                      color: LightModeColors.novoPharmaBlue,
                                                      size: 18,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text("SKU: ${product.sku}", style: const TextStyle(fontSize: 12, color: LightModeColors.novoPharmaGray)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  const Divider(height: 24),
                                  Row(
                                    children: [
                                      // Expiration details trigger
                                      OutlinedButton.icon(
                                        onPressed: () => _openExpirationDialog(product),
                                        icon: Icon(
                                          hasExpirations ? Icons.check_circle : Icons.calendar_today_rounded,
                                          size: 16,
                                          color: hasExpirations ? LightModeColors.success : LightModeColors.novoPharmaBlue,
                                        ),
                                        label: Text(
                                          hasExpirations
                                              ? "${draftItem!.expirations.length} Lot(s) d'exp."
                                              : "Lots d'exp.",
                                          style: TextStyle(
                                            color: hasExpirations ? LightModeColors.success : LightModeColors.novoPharmaBlue,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          side: BorderSide(
                                            color: hasExpirations ? LightModeColors.success : LightModeColors.novoPharmaBlue,
                                          ),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                      const Spacer(),
                                      
                                      // Quantity display badge (tapping opens dialog)
                                      const Text("Qté: ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () => _openExpirationDialog(product),
                                        child: Container(
                                          width: 80,
                                          height: 40,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: LightModeColors.novoPharmaLightGray,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: LightModeColors.lightOutlineVariant),
                                          ),
                                          child: Text(
                                            _controllers[product.id]?.text.isNotEmpty == true
                                                ? _controllers[product.id]!.text
                                                : "0",
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: LightModeColors.novoPharmaBlue,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (hasExpirations) ...[
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: draftItem!.expirations.map((exp) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: LightModeColors.novoPharmaLightBlue,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            "${exp.expirationDate}: ${exp.quantity}",
                                            style: const TextStyle(fontSize: 11, color: LightModeColors.novoPharmaBlue, fontWeight: FontWeight.bold),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                        );
                  }(),
                ),
              ],
            ),
    );
  }
}
