import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/controllers/basket_provider.dart';
import 'package:novopharma/models/basket_item.dart';
import 'package:novopharma/services/gift_eligibility_service.dart';
import 'package:novopharma/widgets/app_network_image.dart';
import 'package:novopharma/theme.dart';

class BasketScreen extends StatefulWidget {
  const BasketScreen({super.key});

  @override
  State<BasketScreen> createState() => _BasketScreenState();
}

class _BasketScreenState extends State<BasketScreen> {
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _prenomController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleCloseBasket(BuildContext context, BasketProvider provider) async {
    final unlockedGifts = provider.eligibleUnlockedGifts;

    String? selectedGiftId;
    String? selectedAssignmentId;
    int giftQty = 1;

    if (unlockedGifts.isNotEmpty) {
      // Prompt gift offer dialog
      final chosen = await showDialog<GiftThresholdEvaluation?>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          GiftThresholdEvaluation? currentSelected = unlockedGifts.first;
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.card_giftcard, color: Colors.amber, size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Cadeau éligible !",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Ce panier est éligible à une offre promotionnelle. Souhaitez-vous attribuer un cadeau ?",
                        style: TextStyle(fontSize: 14, color: LightModeColors.novoPharmaGray),
                      ),
                      const SizedBox(height: 16),
                      ...unlockedGifts.map((eval) {
                        final isSel = currentSelected?.gift.id == eval.gift.id;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSel ? LightModeColors.novoPharmaBlue : Colors.grey.shade300,
                              width: isSel ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: isSel ? LightModeColors.novoPharmaBlue.withOpacity(0.05) : null,
                          ),
                          child: RadioListTile<String>(
                            value: eval.gift.id,
                            groupValue: currentSelected?.gift.id,
                            activeColor: LightModeColors.novoPharmaBlue,
                            onChanged: (val) {
                              setDialogState(() {
                                currentSelected = eval;
                              });
                            },
                            title: Text(
                              eval.gift.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            subtitle: Text(
                              "Stock disponible: ${eval.assignment.assignedStock}",
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        );
                      }),
                      const Divider(height: 24),
                      const Text(
                        "Coordonnées de la cliente (Optionnel)",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nomController,
                        decoration: const InputDecoration(
                          labelText: "Nom",
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _prenomController,
                        decoration: const InputDecoration(
                          labelText: "Prénom",
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: "Téléphone",
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, null),
                    child: const Text("Sans cadeau"),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, currentSelected),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LightModeColors.novoPharmaBlue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Valider avec cadeau"),
                  ),
                ],
              );
            },
          );
        },
      );

      if (chosen != null) {
        selectedGiftId = chosen.gift.id;
        selectedAssignmentId = chosen.assignment.id;
      }
    } else {
      // Standard confirmation without gifts
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Clôturer le panier"),
          content: Text(
            "Voulez-vous clôturer ce panier de ${provider.totalItemsCount} article(s) pour un total de ${provider.totalAmount.toStringAsFixed(3)} TND ?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: LightModeColors.lightPrimary,
                foregroundColor: Colors.white,
              ),
              child: const Text("Confirmer"),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    if (!context.mounted) return;

    // Call Cloud Function closeBasket
    final success = await provider.closeBasket(
      selectedGiftId: selectedGiftId,
      selectedAssignmentId: selectedAssignmentId,
      giftQuantity: giftQty,
      clientNom: _nomController.text.trim(),
      clientPrenom: _prenomController.text.trim(),
      clientPhone: _phoneController.text.trim(),
    );

    if (!context.mounted) return;

    if (success) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      final controller = messenger.showSnackBar(
        SnackBar(
          content: const Text("✅ Panier clôturé avec succès !"),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 5),
          showCloseIcon: true,
        ),
      );
      Timer(const Duration(seconds: 5), () {
        try {
          controller.close();
        } catch (_) {}
      });
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? "Erreur lors de la clôture."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleCancelBasket(BuildContext context, BasketProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Annuler le panier"),
        content: const Text(
          "Êtes-vous sûre de vouloir annuler ce panier ? Les articles ajoutés seront effacés.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Non, continuer"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: LightModeColors.lightError,
              foregroundColor: Colors.white,
            ),
            child: const Text("Oui, annuler"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await provider.cancelBasket();
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Panier client",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Consumer<BasketProvider>(
            builder: (context, provider, _) {
              if (!provider.hasOpenBasket) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_outline, color: LightModeColors.lightError),
                tooltip: "Annuler le panier",
                onPressed: () => _handleCancelBasket(context, provider),
              );
            },
          ),
        ],
      ),
      body: Consumer<BasketProvider>(
        builder: (context, provider, _) {
          final basket = provider.currentBasket;

          if (basket == null || basket.items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: LightModeColors.novoPharmaBlue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shopping_cart_outlined,
                        size: 64,
                        color: LightModeColors.novoPharmaBlue,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Votre panier est vide",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Scannez ou recherchez des produits pour commencer un panier client.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: LightModeColors.novoPharmaGray),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/scanner'),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text("Scanner un produit"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LightModeColors.novoPharmaBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final unlockedGifts = provider.eligibleUnlockedGifts;
          final pendingGifts = provider.pendingThresholdGifts;

          return Column(
            children: [
              // Pharmacy & Visit info pill
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: LightModeColors.novoPharmaBlue.withOpacity(0.08),
                child: Row(
                  children: [
                    const Icon(Icons.storefront, size: 16, color: LightModeColors.novoPharmaBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        basket.pharmacyNameSnapshot ?? "Pharmacie en cours",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: LightModeColors.novoPharmaBlue,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "Panier #${basket.basketNumber ?? 1}",
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: LightModeColors.novoPharmaBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Items List
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Gift banners
                    if (unlockedGifts.isNotEmpty) ...[
                      ...unlockedGifts.map((eval) => Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F8E9),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.card_giftcard, color: Colors.green, size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Cadeau débloqué !",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        eval.gift.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],

                    if (pendingGifts.isNotEmpty) ...[
                      ...pendingGifts.map((eval) => Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: Colors.amber, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        eval.gift.thresholdType == 'amount'
                                            ? "Plus que ${eval.neededAmount.toStringAsFixed(3)} TND pour débloquer :"
                                            : "Plus que ${eval.neededQuantity} produit(s) pour débloquer :",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.brown.shade700,
                                        ),
                                      ),
                                      Text(
                                        eval.gift.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],

                    const Text(
                      "Articles du panier",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    ...basket.items.map((item) => _buildItemCard(context, item, provider)),

                    const SizedBox(height: 16),

                    // Order Summary Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Récapitulatif",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Nombre total d'articles", style: TextStyle(color: Colors.grey)),
                              Text("${provider.totalItemsCount}", style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Points estimés", style: TextStyle(color: Colors.grey)),
                              Text("+${provider.totalPoints.toStringAsFixed(1)} pts",
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Montant Total", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              Text(
                                "${provider.totalAmount.toStringAsFixed(3)} TND",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: LightModeColors.novoPharmaBlue,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, '/scanner'),
                          icon: const Icon(Icons.add),
                          label: const Text("Ajouter"),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: LightModeColors.novoPharmaBlue),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: provider.isLoading ? null : () => _handleCloseBasket(context, provider),
                          icon: provider.isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(
                            provider.isLoading ? "Clôture..." : "Clôturer le panier",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, BasketItem item, BasketProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 50,
              height: 50,
              color: Colors.grey.shade100,
              child: AppNetworkImage(
                imageUrl: item.imageUrl,
                width: 50,
                height: 50,
                fit: BoxFit.contain,
                errorIcon: Icons.image_not_supported_outlined,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.marque != null && item.marque!.isNotEmpty)
                  Text(
                    item.marque!.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: LightModeColors.novoPharmaBlue,
                    ),
                  ),
                Text(
                  item.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  "${item.unitPrice.toStringAsFixed(3)} TND / unité",
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          // Stepper + Total
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${item.lineTotal.toStringAsFixed(3)} TND",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => provider.updateItemQuantity(item.productId, item.quantity - 1),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.remove, size: 16),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      "${item.quantity}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  InkWell(
                    onTap: () => provider.updateItemQuantity(item.productId, item.quantity + 1),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.add, size: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
