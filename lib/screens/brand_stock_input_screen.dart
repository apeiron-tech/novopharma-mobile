import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novopharma/models/product.dart';
import 'package:novopharma/models/stock_models.dart';
import 'package:novopharma/services/product_service.dart';
import 'package:novopharma/widgets/expiration_dialog.dart';
import 'package:novopharma/design/design.dart';

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
        final initialQty = _draftProducts[product.id]?.totalQuantity;
        _controllers[product.id] = TextEditingController(
          text: hasDraft && initialQty != null ? initialQty.toString() : '',
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
              _controllers[product.id]?.text = updatedItem.totalQuantity?.toString() ?? '';
            } else {
              _draftProducts.remove(product.id);
              _controllers[product.id]?.text = '';
            }
          });
        },
      ),
    );
  }

  // Presentation only: the first screenful of rows arrives once per visit.
  // Rows built later (scrolling back up, searching) appear in place.
  bool _rowsArrived = false;

  Widget _arrive(int index, Widget child) {
    if (index >= 6) return child;
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
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: InkAppBar(
        // The brand shares the bar with the save action: shrink a long name
        // before cutting it.
        titleWidget: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                widget.brand,
                maxLines: 1,
                style: AppText.display(size: 22, color: Colors.white),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.pharmacyName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(
                size: 13,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
        leading: GlassIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onTap: () => Navigator.pop(context),
        ),
        actions: [
          PrimaryButton.mint(
            label: "Enregistrer",
            onPressed: _isLoading ? null : _saveProgress,
            height: 44,
            expand: false,
          ),
        ],
      ),
      body: AppBackground(
        child: _isLoading
            ? const SkeletonList(
                count: 4,
                itemHeight: 148,
                padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
              )
            : Column(
                children: [
                  // Info Banner + Search bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Saisissez la quantité totale ou ajoutez des lots avec dates d'expiration.",
                          style: AppText.body(
                            size: 13.5,
                            color: AppColors.textMuted,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                        AppSearchField(
                          controller: _searchController,
                          hintText: "Rechercher par nom ou SKU...",
                        ),
                      ],
                    ),
                  ),

                  // Products List
                  Expanded(
                    child: () {
                      final filteredProducts = _brandProducts.where((product) {
                        final query = _searchQuery.toLowerCase().trim();
                        return product.name.toLowerCase().contains(query) ||
                            product.sku.toLowerCase().contains(query);
                      }).toList();

                      return filteredProducts.isEmpty
                          // Scrolls so it never overflows above the keyboard.
                          ? const Align(
                              alignment: Alignment.topCenter,
                              child: SingleChildScrollView(
                                child: EmptyState(
                                  icon: Icons.search_off_rounded,
                                  title: "Aucun produit trouvé",
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.fromLTRB(
                                20,
                                6,
                                20,
                                MediaQuery.paddingOf(context).bottom + 24,
                              ),
                              itemCount: filteredProducts.length,
                              itemBuilder: (context, index) {
                                final product = filteredProducts[index];
                                final draftItem = _draftProducts[product.id];
                                final hasExpirations = draftItem?.expirations.isNotEmpty ?? false;

                                final hasQty = draftItem != null;

                                // The whole row opens the entry dialog; a
                                // mint wash marks the products already counted.
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _arrive(
                                    index,
                                    SoftCard(
                                      onTap: () => _openExpirationDialog(product),
                                      tint: hasQty ? AppColors.mintTint : null,
                                      padding: const EdgeInsets.all(14),
                                      radius: 24,
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
                                                clipBehavior: Clip.antiAlias,
                                                decoration: BoxDecoration(
                                                  color: AppColors.surface,
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                                child: product.imageUrl.isNotEmpty
                                                    ? CachedNetworkImage(
                                                        imageUrl: product.imageUrl,
                                                        fit: BoxFit.contain,
                                                        placeholder: (context, url) => const SizedBox.expand(),
                                                        errorWidget: (context, url, error) => const Icon(
                                                          Icons.image_not_supported_outlined,
                                                          size: 22,
                                                          color: AppColors.textFaint,
                                                        ),
                                                      )
                                                    : const Icon(
                                                        Icons.image_not_supported_outlined,
                                                        size: 22,
                                                        color: AppColors.textFaint,
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
                                                            style: AppText.body(size: 15, weight: FontWeight.w700, height: 1.25),
                                                          ),
                                                        ),
                                                        if (hasQty) ...[
                                                          const SizedBox(width: 8),
                                                          Icon(
                                                            (draftItem.isPriceOnly || draftItem.totalQuantity == null)
                                                                ? Icons.price_check_rounded
                                                                : Icons.check_circle_rounded,
                                                            color: AppColors.mint,
                                                            size: 22,
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      "SKU: ${product.sku}",
                                                      style: AppText.label(size: 12.5, letterSpacing: 0),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 14),
                                          if (draftItem != null && (draftItem.isPriceOnly || draftItem.totalQuantity == null)) ...[
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Align(
                                                    alignment: Alignment.centerLeft,
                                                    child: _FlexPill(
                                                      icon: draftItem.respectsPrice ? Icons.check_circle_outline : Icons.sell_outlined,
                                                      tone: draftItem.respectsPrice ? Tone.mint : Tone.indigo,
                                                      label: draftItem.respectsPrice
                                                          ? "Prix respecté (${product.price.toStringAsFixed(2)} DT)"
                                                          : "Prix: ${draftItem.sellingPrice?.toStringAsFixed(2) ?? '-'} DT",
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                const _FlexPill(label: "Prix seul", tone: _quietTone),
                                              ],
                                            ),
                                          ] else ...[
                                            Row(
                                              children: [
                                                // Expiration lots
                                                Expanded(
                                                  child: Align(
                                                    alignment: Alignment.centerLeft,
                                                    child: _FlexPill(
                                                      icon: hasExpirations ? Icons.check_circle : Icons.calendar_today_rounded,
                                                      tone: hasExpirations ? Tone.mint : Tone.indigo,
                                                      label: hasExpirations
                                                          ? "${draftItem!.expirations.length} Lot(s) d'exp."
                                                          : "Lots d'exp.",
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),

                                                // Quantity, large enough to read at arm's length
                                                Text(
                                                  "Qté: ",
                                                  style: AppText.label(size: 13.5, weight: FontWeight.w700, color: AppColors.text),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  constraints: const BoxConstraints(minWidth: 84),
                                                  height: 52,
                                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                    color: AppColors.surface,
                                                    borderRadius: BorderRadius.circular(16),
                                                    border: Border.all(
                                                      color: hasQty ? AppColors.mint : AppColors.lineStrong,
                                                      width: 1.4,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    _controllers[product.id]?.text.isNotEmpty == true
                                                        ? _controllers[product.id]!.text
                                                        : "0",
                                                    style: AppText.display(size: 24, color: AppColors.indigoDeep),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (hasExpirations) ...[
                                              const SizedBox(height: 12),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 6,
                                                children: draftItem!.expirations.map((exp) {
                                                  return Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.indigoTint,
                                                      borderRadius: BorderRadius.circular(AppRadii.pill),
                                                    ),
                                                    child: Text(
                                                      "${exp.expirationDate}: ${exp.quantity}",
                                                      style: AppText.label(
                                                        size: 12,
                                                        weight: FontWeight.w700,
                                                        color: AppColors.indigoDeep,
                                                        letterSpacing: 0,
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ],
                                            if (draftItem != null && !draftItem.respectsPrice && draftItem.sellingPrice != null) ...[
                                              const SizedBox(height: 10),
                                              Text(
                                                "Prix réel: ${draftItem.sellingPrice!.toStringAsFixed(2)} DT (Conseillé: ${product.price.toStringAsFixed(2)} DT)",
                                                style: AppText.label(size: 12.5, letterSpacing: 0),
                                              ),
                                            ],
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                    }(),
                  ),
                ],
              ),
      ),
    );
  }
}

/// The quiet tone for labels that describe rather than signal.
const Tone _quietTone = Tone(
  AppColors.textFaint,
  AppColors.textMuted,
  AppColors.line,
);

/// A [TonePill] whose label gives way instead of overflowing — prices and
/// lot counts vary in length.
class _FlexPill extends StatelessWidget {
  final String label;
  final Tone tone;
  final IconData? icon;

  const _FlexPill({required this.label, this.tone = Tone.indigo, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone.tint,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: tone.deep),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label(
                size: 12,
                weight: FontWeight.w700,
                color: tone.deep,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
