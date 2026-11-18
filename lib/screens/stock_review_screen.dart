import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/models/product.dart';
import 'package:novopharma/models/stock_models.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/services/product_service.dart';
import 'package:novopharma/widgets/expiration_dialog.dart';
import 'package:novopharma/design/design.dart';

class StockReviewScreen extends StatefulWidget {
  final String pharmacyId;
  final String pharmacyName;

  const StockReviewScreen({
    super.key,
    required this.pharmacyId,
    required this.pharmacyName,
  });

  @override
  State<StockReviewScreen> createState() => _StockReviewScreenState();
}

class _StockReviewScreenState extends State<StockReviewScreen> {
  final ProductService _productService = ProductService();
  List<Product> _allProducts = [];
  Map<String, ProductStockItem> _draftProducts = {};
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _activeVisitId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch products
      _allProducts = await _productService.getProducts();

      // 2. Fetch SharedPreferences draft
      final prefs = await SharedPreferences.getInstance();
      _activeVisitId = prefs.getString('active_visit_id');

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
      debugPrint("Error loading review data: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draftKey = 'stock_draft_${widget.pharmacyId}';

    if (_draftProducts.isEmpty) {
      await prefs.remove(draftKey);
      return;
    }

    final draftMap = {
      'pharmacyId': widget.pharmacyId,
      'pharmacyName': widget.pharmacyName,
      'lastUpdatedAt': DateTime.now().toIso8601String(),
      'products': _draftProducts.map((key, value) => MapEntry(key, value.toJson())),
    };

    await prefs.setString(draftKey, json.encode(draftMap));
  }

  void _editItem(ProductStockItem item) {
    final product = _allProducts.firstWhere((p) => p.id == item.productId, orElse: () => Product(
      id: item.productId,
      name: item.productName,
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
    ));

    showDialog(
      context: context,
      builder: (context) => ExpirationDialog(
        product: product,
        initialStockItem: item,
        onSave: (updatedItem) {
          setState(() {
            if (updatedItem != null) {
              _draftProducts[item.productId] = updatedItem;
            } else {
              _draftProducts.remove(item.productId);
            }
          });
          _saveDraft();
        },
      ),
    );
  }

  void _deleteItem(String productId) {
    setState(() {
      _draftProducts.remove(productId);
    });
    _saveDraft();
  }

  Future<void> _finalizeAndSync() async {
    if (_draftProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucun produit à synchroniser")),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProfile = authProvider.userProfile;

    if (userProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Utilisateur non connecté ou profil manquant")),
      );
      return;
    }

    setState(() => _isSyncing = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      final productsDataList = _draftProducts.values.map((item) => item.toJson()).toList();

      // 1. Write/merge pharmacies_stock for products that have physical stock entered
      final stockDocRef = firestore.collection('pharmacies_stock').doc(widget.pharmacyId);
      final existingStockDoc = await stockDocRef.get();
      final Map<String, dynamic> existingProductsMap = {};
      if (existingStockDoc.exists) {
        final data = existingStockDoc.data();
        if (data != null && data['products'] is List) {
          for (var p in data['products']) {
            if (p is Map && p['productId'] != null) {
              existingProductsMap[p['productId'].toString()] = p['quantity'];
            }
          }
        }
      }

      for (var item in _draftProducts.values) {
        if (item.totalQuantity != null) {
          existingProductsMap[item.productId] = item.totalQuantity;
        }
      }

      final mergedStockProducts = existingProductsMap.entries.map((e) => {
        'productId': e.key,
        'quantity': e.value,
      }).toList();

      batch.set(stockDocRef, {
        'pharmacyId': widget.pharmacyId,
        'pharmacyName': widget.pharmacyName,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        'updatedBy': userProfile.uid,
        'updaterRole': userProfile.role.isNotEmpty ? userProfile.role : 'Dermo-conseiller',
        'products': mergedStockProducts,
      }, SetOptions(merge: true));

      // 2. Generate stock_history entry
      final historyDocRef = firestore.collection('stock_history').doc();
      batch.set(historyDocRef, {
        'historyId': historyDocRef.id,
        'visitId': _activeVisitId ?? '',
        'dermoId': userProfile.uid,
        'dermoName': userProfile.name,
        'pharmacyId': widget.pharmacyId,
        'pharmacyName': widget.pharmacyName,
        'updatedAt': FieldValue.serverTimestamp(),
        'productsUpdated': productsDataList,
      });

      await batch.commit();

      // 3. Purge Local SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('stock_draft_${widget.pharmacyId}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Inventaire synchronisé avec succès !"),
            backgroundColor: AppColors.mintDeep,
          ),
        );
        // Pop and return true to indicate successful sync
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur de synchronisation: $e"),
            backgroundColor: AppColors.coralDeep,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  // Presentation only: the first screenful of rows arrives once per visit.
  // Rows built later (scrolling back up, after an edit) appear in place.
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
    final itemsList = _draftProducts.values.toList();

    // Figures for the summary, read from the draft already on screen.
    final int totalQuantity = itemsList.fold<int>(0, (total, item) => total + (item.totalQuantity ?? 0));
    final int respectedCount = itemsList.where((item) => item.respectsPrice).length;
    final int notRespectedCount = itemsList.length - respectedCount;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      // The list runs under the frosted submit bar.
      extendBody: true,
      appBar: InkAppBar(
        title: "Récapitulatif Inventaire",
        subtitle: widget.pharmacyName,
        leading: GlassIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onTap: () => Navigator.pop(context),
        ),
        bottom: _isLoading
            ? null
            : PreferredSize(
                // An upper bound: the bar takes only the height it needs.
                preferredSize: Size.fromHeight(itemsList.isEmpty ? 64 : 196),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header visit info
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _activeVisitId != null
                                ? Icons.event_available_rounded
                                : Icons.warning_amber_rounded,
                            size: 17,
                            color: _activeVisitId != null
                                ? AppColors.mintBright
                                : AppColors.amber,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _activeVisitId != null
                                  ? "Visite active ID: $_activeVisitId"
                                  : "Attention: Aucune visite active trouvée.",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body(
                                size: 13,
                                weight: _activeVisitId != null ? FontWeight.w500 : FontWeight.w700,
                                color: Colors.white,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // What is about to be synchronised
                      if (itemsList.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SoftCard(
                          style: GlassStyle.dark,
                          blur: Glass.frost,
                          radius: AppRadii.md,
                          shadow: false,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                flex: 2,
                                child: StatBlock(
                                  label: "Qté",
                                  value: formatPoints(totalQuantity),
                                  onDark: true,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 3,
                                child: StatBlock(
                                  label: "Prix respecté",
                                  value: '$respectedCount',
                                  onDark: true,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 3,
                                child: StatBlock(
                                  label: "Prix non respecté",
                                  value: '$notRespectedCount',
                                  onDark: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
      body: AppBackground(
        child: _isLoading
            ? const SkeletonList(
                count: 4,
                itemHeight: 150,
                padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
              )
            // List of items in draft
            : itemsList.isEmpty
                ? const EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: "Aucun produit dans le panier de révision",
                  )
                : Builder(
                    // Inside the body, so the bottom inset includes the
                    // submit bar.
                    builder: (context) => ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        16,
                        20,
                        MediaQuery.paddingOf(context).bottom + 20,
                      ),
                      itemCount: itemsList.length,
                      itemBuilder: (context, index) {
                        final item = itemsList[index];
                        final hasExpirations = item.expirations.isNotEmpty;

                        final matchedProduct = _allProducts.firstWhere(
                          (p) => p.id == item.productId,
                          orElse: () => Product(
                            id: item.productId,
                            name: item.productName,
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

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _arrive(
                            index,
                            SoftCard(
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
                                        width: 52,
                                        height: 52,
                                        margin: const EdgeInsets.only(right: 12),
                                        clipBehavior: Clip.antiAlias,
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: matchedProduct.imageUrl.isNotEmpty
                                            ? CachedNetworkImage(
                                                imageUrl: matchedProduct.imageUrl,
                                                fit: BoxFit.contain,
                                                placeholder: (context, url) => const SizedBox.expand(),
                                                errorWidget: (context, url, error) => const Icon(
                                                  Icons.image_not_supported_outlined,
                                                  size: 20,
                                                  color: AppColors.textFaint,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.image_not_supported_outlined,
                                                size: 20,
                                                color: AppColors.textFaint,
                                              ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.productName,
                                              style: AppText.body(size: 15, weight: FontWeight.w700, height: 1.25),
                                            ),
                                            const SizedBox(height: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: AppColors.indigoTint,
                                                borderRadius: BorderRadius.circular(AppRadii.pill),
                                              ),
                                              child: Text(
                                                item.totalQuantity != null ? "Qté: ${item.totalQuantity}" : "Prix uniquement",
                                                style: AppText.display(size: 15, color: AppColors.indigoDeep),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (hasExpirations) ...[
                                    const SizedBox(height: 14),
                                    Text(
                                      "Lots d'expiration :",
                                      style: AppText.label(size: 12.5, letterSpacing: 0),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        ...item.expirations.map((exp) {
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
                                          }),
                                        if (item.totalQuantity != null && item.totalQuantity! > item.expirations.fold<int>(0, (acc, exp) => acc + exp.quantity))
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: AppColors.line,
                                              borderRadius: BorderRadius.circular(AppRadii.pill),
                                            ),
                                            child: Text(
                                              "Sans date: ${item.totalQuantity! - item.expirations.fold<int>(0, (acc, exp) => acc + exp.quantity)}",
                                              style: AppText.label(size: 12, weight: FontWeight.w700, letterSpacing: 0),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: _FlexPill(
                                      icon: item.respectsPrice ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                                      tone: item.respectsPrice ? Tone.mint : Tone.coral,
                                      label: item.respectsPrice ? "Prix respecté" : "Prix non respecté",
                                    ),
                                  ),
                                  if (!item.respectsPrice && item.sellingPrice != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      "Vente: ${item.sellingPrice!.toStringAsFixed(2)} DT (Diff: ${item.priceDifference != null ? (item.priceDifference! > 0 ? '+' : '') + item.priceDifference!.toStringAsFixed(2) : '0.00'} DT)",
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.label(size: 12.5, letterSpacing: 0),
                                    ),
                                  ],
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    width: double.infinity,
                                    child: Wrap(
                                      alignment: WrapAlignment.end,
                                      spacing: 10,
                                      runSpacing: 8,
                                      children: [
                                        SecondaryButton(
                                          label: "Modifier",
                                          icon: Icons.edit_outlined,
                                          height: 44,
                                          expand: false,
                                          onPressed: () => _editItem(item),
                                        ),
                                        SecondaryButton(
                                          label: "Supprimer",
                                          icon: Icons.delete_outline_rounded,
                                          tone: Tone.coral,
                                          height: 44,
                                          expand: false,
                                          onPressed: () => _deleteItem(item.productId),
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
                    ),
                  ),
      ),

      // Finalize sync button
      bottomNavigationBar: !_isLoading && itemsList.isNotEmpty
          ? GlassBottomBar(
              // While the sync runs the action gives way to its status, so
              // it cannot be sent twice.
              child: AnimatedSwitcher(
                duration: AppMotion.fast,
                child: _isSyncing
                    ? SizedBox(
                        key: const ValueKey('syncing'),
                        height: 56,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CapsuleLoader(size: 34),
                            const SizedBox(width: 14),
                            Flexible(
                              child: Text(
                                "Synchronisation en cours...",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.body(size: 16, weight: FontWeight.w700, height: 1.1),
                              ),
                            ),
                          ],
                        ),
                      )
                    : PrimaryButton(
                        key: const ValueKey('submit'),
                        label: "Finaliser & Synchroniser",
                        icon: Icons.cloud_upload_rounded,
                        onPressed: _isSyncing ? null : _finalizeAndSync,
                      ),
              ),
            )
          : null,
    );
  }
}

/// A [TonePill] whose label gives way instead of overflowing.
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
