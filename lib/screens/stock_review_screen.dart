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
import 'package:novopharma/theme.dart';

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

      // 1. Write/overwrite pharmacies_stock
      final stockDocRef = firestore.collection('pharmacies_stock').doc(widget.pharmacyId);
      batch.set(stockDocRef, {
        'pharmacyId': widget.pharmacyId,
        'pharmacyName': widget.pharmacyName,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        'updatedBy': userProfile.uid,
        'updaterRole': userProfile.role.isNotEmpty ? userProfile.role : 'Dermo-conseiller',
        'products': productsDataList,
      });

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
            backgroundColor: LightModeColors.success,
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
            backgroundColor: LightModeColors.lightError,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsList = _draftProducts.values.toList();

    return Scaffold(
      backgroundColor: LightModeColors.novoPharmaLightGray,
      appBar: AppBar(
        title: const Text("Récapitulatif Inventaire", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                // Header pharmacy info
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.pharmacyName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: LightModeColors.dashboardTextPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _activeVisitId != null
                            ? "Visite active ID: $_activeVisitId"
                            : "Attention: Aucune visite active trouvée.",
                        style: TextStyle(
                          fontSize: 12,
                          color: _activeVisitId != null 
                              ? LightModeColors.novoPharmaGray 
                              : LightModeColors.lightError,
                          fontWeight: _activeVisitId != null ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // List of items in draft
                Expanded(
                  child: itemsList.isEmpty
                      ? const Center(
                          child: Text("Aucun produit dans le panier de révision", style: TextStyle(color: LightModeColors.novoPharmaGray)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: LightModeColors.lightOutlineVariant),
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
                                        width: 50,
                                        height: 50,
                                        margin: const EdgeInsets.only(right: 12),
                                        decoration: BoxDecoration(
                                          color: LightModeColors.novoPharmaLightGray,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: LightModeColors.lightOutlineVariant),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: matchedProduct.imageUrl.isNotEmpty
                                              ? CachedNetworkImage(
                                                  imageUrl: matchedProduct.imageUrl,
                                                  fit: BoxFit.contain,
                                                  placeholder: (context, url) => const Center(
                                                    child: SizedBox(
                                                      width: 14,
                                                      height: 14,
                                                      child: CircularProgressIndicator(strokeWidth: 2),
                                                    ),
                                                  ),
                                                  errorWidget: (context, url, error) => const Icon(
                                                    Icons.image_not_supported_outlined,
                                                    size: 18,
                                                    color: LightModeColors.novoPharmaGray,
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.image_not_supported_outlined,
                                                  size: 18,
                                                  color: LightModeColors.novoPharmaGray,
                                                ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          item.productName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: LightModeColors.dashboardTextPrimary),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: LightModeColors.novoPharmaLightBlue,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          "Qté: ${item.totalQuantity}",
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: LightModeColors.novoPharmaBlue),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (hasExpirations) ...[
                                    const SizedBox(height: 12),
                                    const Text("Lots d'expiration :", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: LightModeColors.novoPharmaGray)),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        ...item.expirations.map((exp) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: LightModeColors.novoPharmaLightGray,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              "${exp.expirationDate}: ${exp.quantity}",
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: LightModeColors.dashboardTextPrimary),
                                            ),
                                          );
                                        }).toList(),
                                        if (item.totalQuantity > item.expirations.fold<int>(0, (sum, exp) => sum + exp.quantity))
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: LightModeColors.novoPharmaLightGray,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: LightModeColors.lightOutlineVariant),
                                            ),
                                            child: Text(
                                              "Sans date: ${item.totalQuantity - item.expirations.fold<int>(0, (sum, exp) => sum + exp.quantity)}",
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: LightModeColors.novoPharmaGray),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: item.respectsPrice
                                              ? LightModeColors.success.withOpacity(0.1)
                                              : LightModeColors.lightError.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: item.respectsPrice
                                                ? LightModeColors.success.withOpacity(0.3)
                                                : LightModeColors.lightError.withOpacity(0.3),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              item.respectsPrice ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                                              size: 14,
                                              color: item.respectsPrice ? LightModeColors.success : LightModeColors.lightError,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              item.respectsPrice ? "Prix respecté" : "Prix non respecté",
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: item.respectsPrice ? LightModeColors.success : LightModeColors.lightError,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!item.respectsPrice && item.sellingPrice != null) ...[
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            "Vente: ${item.sellingPrice!.toStringAsFixed(2)} DT (Diff: ${item.priceDifference != null ? (item.priceDifference! > 0 ? '+' : '') + item.priceDifference!.toStringAsFixed(2) : '0.00'} DT)",
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: LightModeColors.novoPharmaGray,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _editItem(item),
                                        icon: const Icon(Icons.edit_outlined, size: 16, color: LightModeColors.novoPharmaBlue),
                                        label: const Text("Modifier", style: TextStyle(fontSize: 13, color: LightModeColors.novoPharmaBlue)),
                                      ),
                                      const SizedBox(width: 16),
                                      TextButton.icon(
                                        onPressed: () => _deleteItem(item.productId),
                                        icon: const Icon(Icons.delete_outline, size: 16, color: LightModeColors.lightError),
                                        label: const Text("Supprimer", style: TextStyle(fontSize: 13, color: LightModeColors.lightError)),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            );
                          },
                        ),
                ),
                
                // Finalize sync button
                if (itemsList.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isSyncing ? null : _finalizeAndSync,
                        icon: _isSyncing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                        label: Text(
                          _isSyncing ? "Synchronisation en cours..." : "Finaliser & Synchroniser",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LightModeColors.novoPharmaBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
