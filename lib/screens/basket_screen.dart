import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/controllers/basket_provider.dart';
import 'package:novopharma/models/basket_item.dart';
import 'package:novopharma/services/gift_eligibility_service.dart';
import 'package:novopharma/widgets/app_network_image.dart';
import 'package:novopharma/design/design.dart';

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
      GiftThresholdEvaluation? currentSelected = unlockedGifts.first;
      final chosen = await showGlassDialog<GiftThresholdEvaluation?>(
        context: context,
        barrierDismissible: false,
        padding: const EdgeInsets.all(22),
        child: StatefulBuilder(
          builder: (ctx, setDialogState) {
            return ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const BlisterIcon(
                          icon: Icons.card_giftcard_rounded,
                          tone: Tone.amber,
                          size: 46,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Cadeau éligible !",
                            style: AppText.display(size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "Ce panier est éligible à une offre promotionnelle. Souhaitez-vous attribuer un cadeau ?",
                      style: AppText.body(
                        size: 14.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...unlockedGifts.map((eval) {
                      final isSel = currentSelected?.gift.id == eval.gift.id;
                      return AnimatedContainer(
                        duration: AppMotion.fast,
                        margin: const EdgeInsets.only(bottom: 8),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSel ? AppColors.amber : AppColors.line,
                            width: isSel ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          color: isSel
                              ? AppColors.amberTint
                              : Colors.white.withValues(alpha: 0.66),
                        ),
                        child: RadioListTile<String>(
                          value: eval.gift.id,
                          groupValue: currentSelected?.gift.id,
                          activeColor: AppColors.amberDeep,
                          onChanged: (val) {
                            setDialogState(() {
                              currentSelected = eval;
                            });
                          },
                          title: Text(
                            eval.gift.title,
                            style: AppText.body(
                              size: 14.5,
                              weight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                          subtitle: Text(
                            "Stock disponible: ${eval.assignment.assignedStock}",
                            style: AppText.label(
                              size: 12.5,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      );
                    }),
                    const Divider(height: 24),
                    Text(
                      "Coordonnées de la cliente (Optionnel)",
                      style: AppText.label(
                        size: 13.5,
                        color: AppColors.text,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nomController,
                      decoration: const InputDecoration(
                        labelText: "Nom",
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _prenomController,
                      decoration: const InputDecoration(
                        labelText: "Prénom",
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: "Téléphone",
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 22),
                    PrimaryButton(
                      label: "Valider avec cadeau",
                      icon: Icons.check_rounded,
                      height: 52,
                      onPressed: () => Navigator.pop(ctx, currentSelected),
                    ),
                    const SizedBox(height: 8),
                    SecondaryButton(
                      label: "Sans cadeau",
                      height: 48,
                      onPressed: () => Navigator.pop(ctx, null),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      if (chosen != null) {
        selectedGiftId = chosen.gift.id;
        selectedAssignmentId = chosen.assignment.id;
      }
    } else {
      // Standard confirmation without gifts
      final confirm = await showGlassDialog<bool>(
        context: context,
        child: Builder(
          builder: (ctx) => ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: BlisterIcon(
                    icon: Icons.shopping_bag_rounded,
                    tone: Tone.peach,
                    size: 52,
                  ),
                ),
                const SizedBox(height: 16),
                Text("Clôturer le panier", style: AppText.display(size: 21)),
                const SizedBox(height: 8),
                Text(
                  "Voulez-vous clôturer ce panier de ${provider.totalItemsCount} article(s) pour un total de ${provider.totalAmount.toStringAsFixed(3)} TND ?",
                  style: AppText.body(size: 14.5, color: AppColors.textMuted),
                ),
                const SizedBox(height: 22),
                PrimaryButton(
                  label: "Confirmer",
                  icon: Icons.check_rounded,
                  height: 52,
                  onPressed: () => Navigator.pop(ctx, true),
                ),
                const SizedBox(height: 10),
                SecondaryButton(
                  label: "Annuler",
                  height: 48,
                  onPressed: () => Navigator.pop(ctx, false),
                ),
              ],
            ),
          ),
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
      // The basket is closed and its points are earned.
      celebrate(context);
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      final controller = messenger.showSnackBar(
        const SnackBar(
          content: Text("✅ Panier clôturé avec succès !"),
          backgroundColor: AppColors.mintDeep,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 5),
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
          backgroundColor: AppColors.coralDeep,
        ),
      );
    }
  }

  Future<void> _handleCancelBasket(BuildContext context, BasketProvider provider) async {
    final confirm = await showGlassDialog<bool>(
      context: context,
      child: Builder(
        builder: (ctx) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: BlisterIcon(
                  icon: Icons.delete_outline_rounded,
                  tone: Tone.coral,
                  size: 52,
                ),
              ),
              const SizedBox(height: 16),
              Text("Annuler le panier", style: AppText.display(size: 21)),
              const SizedBox(height: 8),
              Text(
                "Êtes-vous sûre de vouloir annuler ce panier ? Les articles ajoutés seront effacés.",
                style: AppText.body(size: 14.5, color: AppColors.textMuted),
              ),
              const SizedBox(height: 22),
              PrimaryButton.coral(
                label: "Oui, annuler",
                icon: Icons.delete_outline_rounded,
                height: 52,
                onPressed: () => Navigator.pop(ctx, true),
              ),
              const SizedBox(height: 10),
              SecondaryButton(
                label: "Non, continuer",
                height: 48,
                onPressed: () => Navigator.pop(ctx, false),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      await provider.cancelBasket();
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }

  // Presentation only: the first screenful arrives once; rows created later
  // (scrolling back, a quantity change) appear immediately.
  bool _listArrived = false;

  Widget _arrive(int index, Widget child) {
    if (index > 5) return child;
    // Read the flag when the row mounts, not when the list is built, so a
    // row that scrolls back into view does not replay its entrance.
    return Builder(
      builder: (context) => Entrance(
        delay: _listArrived
            ? Duration.zero
            : Duration(milliseconds: 60 * index),
        duration: _listArrived ? Duration.zero : AppMotion.slow,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      extendBody: true,
      appBar: InkAppBar(
        titleWidget: Consumer<BasketProvider>(
          builder: (context, provider, _) {
            return Row(
              children: [
                Flexible(
                  child: Text(
                    "Panier client",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.display(size: 22, color: Colors.white),
                  ),
                ),
                if (provider.hasOpenBasket) ...[
                  const SizedBox(width: 10),
                  // Item count
                  Container(
                    height: 28,
                    constraints: const BoxConstraints(minWidth: 28),
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Text(
                      "${provider.totalItemsCount}",
                      style: AppText.display(
                        size: 14,
                        color: Colors.white,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        actions: [
          Consumer<BasketProvider>(
            builder: (context, provider, _) {
              if (!provider.hasOpenBasket) return const SizedBox.shrink();
              return GlassIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: "Annuler le panier",
                onTap: () => _handleCancelBasket(context, provider),
              );
            },
          ),
        ],
      ),
      body: AppBackground(
        accent: Tone.peach,
        child: Consumer<BasketProvider>(
          builder: (context, provider, _) {
            final basket = provider.currentBasket;

            if (basket == null || basket.items.isEmpty) {
              return EmptyState(
                icon: Icons.shopping_cart_rounded,
                tone: Tone.peach,
                title: "Votre panier est vide",
                message:
                    "Scannez ou recherchez des produits pour commencer un panier client.",
                actionLabel: "Scanner un produit",
                onAction: () => Navigator.pushNamed(context, '/scanner'),
              );
            }

            final unlockedGifts = provider.eligibleUnlockedGifts;
            final pendingGifts = provider.pendingThresholdGifts;

            if (!_listArrived) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _listArrived = true,
              );
            }
            var order = 0;

            // Items List
            return ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.paddingOf(context).bottom + 20,
              ),
              children: [
                // Gift banners
                if (unlockedGifts.isNotEmpty) ...[
                  ...unlockedGifts.map(
                    (eval) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _arrive(
                        order++,
                        SoftCard(
                          tint: AppColors.amberTint,
                          radius: AppRadii.md + 2,
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              const BlisterIcon(
                                icon: Icons.card_giftcard_rounded,
                                tone: Tone.amber,
                                size: 46,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Cadeau débloqué !",
                                      style: AppText.label(
                                        size: 13,
                                        weight: FontWeight.w700,
                                        color: AppColors.amberDeep,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      eval.gift.title,
                                      style: AppText.body(
                                        size: 15.5,
                                        weight: FontWeight.w700,
                                        height: 1.25,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                if (pendingGifts.isNotEmpty) ...[
                  ...pendingGifts.map(
                    (eval) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _arrive(
                        order++,
                        SoftCard(
                          radius: AppRadii.md + 2,
                          shadow: false,
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              const TintIcon(
                                icon: Icons.lock_outline_rounded,
                                tone: Tone.amber,
                                size: 42,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      eval.gift.thresholdType == 'amount'
                                          ? "Plus que ${eval.neededAmount.toStringAsFixed(3)} TND pour débloquer :"
                                          : "Plus que ${eval.neededQuantity} produit(s) pour débloquer :",
                                      style: AppText.label(
                                        size: 12.5,
                                        weight: FontWeight.w600,
                                        color: AppColors.amberDeep,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      eval.gift.title,
                                      style: AppText.body(
                                        size: 14.5,
                                        weight: FontWeight.w700,
                                        height: 1.25,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                // Pharmacy & Visit info
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.storefront_rounded,
                        size: 18,
                        color: AppColors.indigoDeep,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          basket.pharmacyNameSnapshot ?? "Pharmacie en cours",
                          style: AppText.label(
                            size: 13.5,
                            weight: FontWeight.w700,
                            color: AppColors.indigoDeep,
                            letterSpacing: 0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TonePill(label: "Panier #${basket.basketNumber ?? 1}"),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    "Articles du panier",
                    style: AppText.display(size: 20),
                  ),
                ),
                const SizedBox(height: 12),

                ...basket.items.map(
                  (item) => _arrive(
                    order++,
                    _buildItemCard(context, item, provider),
                  ),
                ),

                const SizedBox(height: 8),

                // Order Summary Card
                SoftCard(
                  radius: AppRadii.md + 2,
                  shadow: false,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Récapitulatif", style: AppText.display(size: 17)),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              "Nombre total d'articles",
                              style: AppText.body(
                                size: 14.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "${provider.totalItemsCount}",
                            style: AppText.display(size: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              "Points estimés",
                              style: AppText.body(
                                size: 14.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "+${provider.totalPoints.toStringAsFixed(1)} pts",
                            style: AppText.display(
                              size: 16,
                              color: AppColors.mintDeep,
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Divider(height: 1, color: AppColors.line),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              "Montant Total",
                              style: AppText.body(
                                size: 15.5,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "${provider.totalAmount.toStringAsFixed(3)} TND",
                            style: AppText.display(size: 19),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),

      // Bottom Actions
      bottomNavigationBar: Consumer<BasketProvider>(
        builder: (context, provider, _) {
          final basket = provider.currentBasket;
          if (basket == null || basket.items.isEmpty) {
            return const SizedBox.shrink();
          }

          return GlassBottomBar(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: StatBlock(
                        label: "Montant Total",
                        value: "${provider.totalAmount.toStringAsFixed(3)} TND",
                      ),
                    ),
                    const SizedBox(width: 16),
                    StatBlock(
                      label: "Points estimés",
                      value: "+${provider.totalPoints.toStringAsFixed(1)} pts",
                      tone: Tone.mint,
                      alignment: CrossAxisAlignment.end,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // A tighter SecondaryButton: at 360pt it has to leave
                    // room for the full "Clôturer le panier" label.
                    Pressable(
                      semanticLabel: "Ajouter",
                      onTap: () => Navigator.pushNamed(context, '/scanner'),
                      child: Glass(
                        tint: Color.lerp(AppColors.indigoTint, Colors.white, 0.35),
                        shadow: false,
                        height: 56,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        padding: const EdgeInsets.only(left: 12, right: 16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.add_rounded,
                              color: AppColors.indigoDeep,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Ajouter",
                              style: AppText.body(
                                size: 15,
                                weight: FontWeight.w700,
                                color: AppColors.indigoDeep,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton(
                        label: provider.isLoading ? "Clôture..." : "Clôturer le panier",
                        loading: provider.isLoading,
                        gradient: Tone.peach.gradient,
                        glowColor: AppColors.peach,
                        foreground: AppColors.ink,
                        // PrimaryButton ignores taps while it is loading.
                        onPressed: () => _handleCloseBasket(context, provider),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, BasketItem item, BasketProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        radius: AppRadii.md + 2,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  child: Container(
                    width: 60,
                    height: 60,
                    color: AppColors.surface,
                    child: AppNetworkImage(
                      imageUrl: item.imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.contain,
                      errorIcon: Icons.image_not_supported_outlined,
                      errorIconColor: AppColors.textFaint,
                      backgroundColor: AppColors.surface,
                      placeholder: (context, url) =>
                          const SkeletonBox(width: 60, height: 60, radius: 0),
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
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            item.marque!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.label(
                              size: 12,
                              weight: FontWeight.w700,
                              color: AppColors.indigo,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      Text(
                        item.name,
                        style: AppText.body(
                          size: 14.5,
                          weight: FontWeight.w700,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${item.unitPrice.toStringAsFixed(3)} TND / unité",
                        style: AppText.label(
                          size: 12.5,
                          weight: FontWeight.w500,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Total, points + Stepper
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        "${item.lineTotal.toStringAsFixed(3)} TND",
                        style: AppText.display(size: 17),
                      ),
                      TonePill(
                        label: "+${item.pointsEarned.toStringAsFixed(1)} pts",
                        tone: Tone.mint,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    border: Border.all(color: Colors.white),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // At a quantity of one, minus removes the line.
                      _StepButton(
                        icon: item.quantity <= 1
                            ? Icons.delete_outline_rounded
                            : Icons.remove_rounded,
                        tone: item.quantity <= 1 ? Tone.coral : Tone.indigo,
                        semanticLabel: item.quantity <= 1
                            ? MaterialLocalizations.of(context)
                                .deleteButtonTooltip
                            : '-',
                        onTap: () => provider.updateItemQuantity(item.productId, item.quantity - 1),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 34),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            "${item.quantity}",
                            textAlign: TextAlign.center,
                            style: AppText.display(size: 18),
                          ),
                        ),
                      ),
                      _StepButton(
                        icon: Icons.add_rounded,
                        tone: Tone.indigo,
                        semanticLabel: '+',
                        onTap: () => provider.updateItemQuantity(item.productId, item.quantity + 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One round half of a quantity stepper: a 44pt target with a tinted disc.
class _StepButton extends StatelessWidget {
  final IconData icon;
  final Tone tone;
  final String semanticLabel;
  final VoidCallback onTap;

  const _StepButton({
    required this.icon,
    required this.tone,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.9,
      semanticLabel: semanticLabel,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: tone.tint, shape: BoxShape.circle),
        child: Icon(icon, size: 22, color: tone.deep),
      ),
    );
  }
}
