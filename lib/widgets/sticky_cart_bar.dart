import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/controllers/basket_provider.dart';
import 'package:novopharma/design/design.dart';

/// The open basket, floating above the dock: an indigo-tinted pane of smoked
/// glass that shows what is in the basket and takes you to it.
class StickyCartBar extends StatelessWidget {
  const StickyCartBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BasketProvider>(
      builder: (context, basketProvider, child) {
        if (!basketProvider.hasOpenBasket) {
          return const SizedBox.shrink();
        }

        final count = basketProvider.totalItemsCount;
        final total = basketProvider.totalAmount;
        final hasGifts = basketProvider.eligibleUnlockedGifts.isNotEmpty;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Pressable(
            semanticLabel: "Panier en cours ($count art.)",
            onTap: () {
              Navigator.pushNamed(context, '/basket');
            },
            child: Glass(
              style: GlassStyle.smoked,
              blur: Glass.frost,
              tint: AppColors.indigoDeep,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Icon(
                          Icons.shopping_bag_rounded,
                          color: Colors.white,
                          size: 21,
                        ),
                      ),
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.coral,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            border: Border.all(
                              color: AppColors.indigoDeep,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            '$count',
                            textAlign: TextAlign.center,
                            style: AppText.display(
                              size: 10.5,
                              color: Colors.white,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Panier en cours ($count art.)",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.label(
                            size: 12.5,
                            color: Colors.white.withValues(alpha: 0.84),
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "${total.toStringAsFixed(3)} TND",
                                  maxLines: 1,
                                  style: AppText.display(
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            if (hasGifts) ...[
                              const SizedBox(width: 8),
                              const TonePill(label: "Cadeau", tone: Tone.amber),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    height: 40,
                    padding: const EdgeInsets.only(left: 14, right: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Voir",
                          style: AppText.body(
                            size: 14,
                            weight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 16,
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
    );
  }
}
