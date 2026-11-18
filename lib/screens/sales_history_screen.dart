import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/controllers/sales_history_provider.dart';
import 'package:novopharma/design/design.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';
import 'package:novopharma/models/basket.dart';
import 'package:novopharma/models/basket_item.dart';
import 'package:novopharma/models/gift.dart';
import 'package:novopharma/models/sale.dart';
import 'package:novopharma/screens/product_screen.dart';
import 'package:novopharma/services/basket_service.dart';
import 'package:novopharma/services/gift_service.dart';
import 'package:novopharma/services/product_service.dart';
import 'package:novopharma/widgets/app_network_image.dart';
import 'package:novopharma/widgets/bottom_navigation_bar.dart';
import 'package:provider/provider.dart';

// ---------------------------------------------------------------------------
// Grouping models for Sales History (Single direct sales vs Grouped baskets)
// ---------------------------------------------------------------------------
abstract class HistoryEntry {
  DateTime get date;
}

class SingleSaleEntry extends HistoryEntry {
  final Sale sale;
  SingleSaleEntry(this.sale);
  @override
  DateTime get date => sale.saleDate;
}

class BasketEntry extends HistoryEntry {
  final String basketId;
  final List<Sale> sales;
  final DateTime basketDate;
  final double totalAmount;
  final int totalQuantity;
  final double totalPoints;
  final String status;

  BasketEntry({
    required this.basketId,
    required this.sales,
    required this.basketDate,
    required this.totalAmount,
    required this.totalQuantity,
    required this.totalPoints,
    required this.status,
  });

  @override
  DateTime get date => basketDate;
}

/// The quiet tone for states that are neither a gain nor a problem
/// (cancelled sales and baskets).
const Tone _neutralTone = Tone(
  AppColors.textFaint,
  AppColors.textMuted,
  AppColors.line,
);

class _SaleGiftInfo {
  final String title;
  final int quantity;
  final String operationId;

  const _SaleGiftInfo({
    required this.title,
    required this.quantity,
    required this.operationId,
  });
}

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final ProductService _productService = ProductService();
  final GiftService _giftService = GiftService();
  final BasketService _basketService = BasketService();

  final Map<String, Future<String?>> _productImageFutures = {};
  final Map<String, Future<_SaleGiftInfo?>> _saleGiftFutures = {};
  final Map<String, Future<Gift?>> _giftByIdFutures = {};

  bool _isFilterExpanded = true;

  // Presentation only: the first screenful of rows arrives once per visit.
  // Rows built later (scrolling back up, a new period) appear in place.
  bool _rowsArrived = false;

  Widget _arrive(int index, Widget child) {
    if (index >= 6) return child;
    final play = !_rowsArrived;
    if (play) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _rowsArrived = true);
    }
    return Entrance(
      delay: play ? Duration(milliseconds: 60 * index) : Duration.zero,
      duration: play ? AppMotion.slow : Duration.zero,
      child: child,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.firebaseUser != null) {
        Provider.of<SalesHistoryProvider>(
          context,
          listen: false,
        ).fetchSalesHistory(authProvider.firebaseUser!.uid);
      }
    });
  }

  Future<void> _refreshSalesHistory() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.firebaseUser?.uid;
    if (userId == null) return;
    _saleGiftFutures.clear();
    await Provider.of<SalesHistoryProvider>(
      context,
      listen: false,
    ).fetchSalesHistory(userId);
  }

  Future<String?> _getProductImage(String productId) {
    if (productId.isEmpty) return Future.value(null);
    return _productImageFutures.putIfAbsent(productId, () async {
      try {
        final product = await _productService.getProductById(productId);
        final imageUrl = product?.imageUrl.trim() ?? '';
        return imageUrl.isNotEmpty ? imageUrl : null;
      } catch (e) {
        debugPrint('Error fetching product image for ID $productId: $e');
        return null;
      }
    });
  }

  Future<_SaleGiftInfo?> _getSaleGiftInfo(String saleId) {
    if (saleId.isEmpty) return Future.value(null);
    return _saleGiftFutures.putIfAbsent(saleId, () async {
      try {
        final op = await _giftService.getGiftOperationBySaleId(saleId);
        if (op == null) return null;
        final String giftId = (op['giftId'] ?? '').toString();
        final int qty = (op['quantity'] as num?)?.toInt() ?? 0;
        final String docId = (op['id'] ?? '').toString();

        String giftTitle = 'Cadeau';
        if (giftId.isNotEmpty) {
          final gift = await _giftByIdFutures.putIfAbsent(
            giftId,
            () => _giftService.getGiftById(giftId),
          );
          if (gift != null && gift.title.trim().isNotEmpty) {
            giftTitle = gift.title.trim();
          }
        }

        return _SaleGiftInfo(
          title: giftTitle,
          quantity: qty,
          operationId: docId,
        );
      } catch (e) {
        debugPrint('Error fetching gift info for sale $saleId: $e');
        return null;
      }
    });
  }

  String _formatPoints(double points) {
    if (points == points.roundToDouble()) {
      return points.toInt().toString();
    }
    return points.toStringAsFixed(1);
  }

  String _formatLocalizedDate(BuildContext context, DateTime date, {bool includeTime = false}) {
    final locale = Localizations.localeOf(context).languageCode;
    try {
      final datePart = DateFormat.yMMMd(locale).format(date);
      if (!includeTime) return datePart;
      final timePart = DateFormat('HH:mm', locale).format(date);
      return '$datePart • $timePart';
    } catch (_) {
      final datePart = DateFormat.yMMMd().format(date);
      if (!includeTime) return datePart;
      return '$datePart • ${DateFormat('HH:mm').format(date)}';
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final provider = Provider.of<SalesHistoryProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.firebaseUser?.uid;

    if (userId == null) return;

    final now = DateTime.now();
    final minBound = !isStartDate && provider.startDate != null
        ? provider.startDate!
        : DateTime(2020);
    final maxBound = isStartDate && provider.endDate != null && provider.endDate!.isBefore(now)
        ? provider.endDate!
        : now;

    DateTime initialDate =
        (isStartDate ? provider.startDate : provider.endDate) ?? maxBound;
    if (initialDate.isBefore(minBound)) initialDate = minBound;
    if (initialDate.isAfter(maxBound)) initialDate = maxBound;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: minBound,
      lastDate: maxBound,
      builder: (ctx, child) {
        final theme = Theme.of(ctx);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: AppColors.indigo,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.text,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              headerBackgroundColor: AppColors.ink,
              headerForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      if (isStartDate) {
        provider.setStartDate(pickedDate);
      } else {
        provider.setEndDate(pickedDate);
      }
      provider.fetchSalesHistory(userId);
    }
  }

  void _showDeleteConfirmationDialog(BuildContext context, Sale sale) {
    final l10n = AppLocalizations.of(context)!;
    showGlassDialog(
      context: context,
      child: Builder(
        builder: (BuildContext ctx) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const TintIcon(
                    icon: Icons.delete_outline_rounded,
                    tone: Tone.coral,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      l10n.confirmDeletion,
                      style: AppText.display(size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                l10n.confirmDeletionMessage,
                style: AppText.body(
                  size: 15,
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: l10n.cancel,
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PrimaryButton.coral(
                      label: l10n.delete,
                      height: 52,
                      onPressed: () {
                        Provider.of<SalesHistoryProvider>(
                          context,
                          listen: false,
                        ).deleteSale(sale);
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showGlassDialog(
      context: context,
      child: Builder(
        builder: (BuildContext ctx) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const TintIcon(icon: Icons.info_outline_rounded),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Information',
                      style: AppText.display(size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Après validation, vos points sont automatiquement ajoutés à votre solde de points utilisables et peuvent être échangés en crédits Pluxee.',
                style: AppText.body(
                  size: 15,
                  color: AppColors.textMuted,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 22),
              PrimaryButton(
                label: 'Fermer',
                height: 52,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showBasketDetailsDialog(BuildContext context, String basketId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BasketDetailsSheet(
        basketId: basketId,
        basketService: _basketService,
        getProductImage: _getProductImage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BottomNavigationScaffoldWrapper(
      currentIndex: 4, // History tab index
      onTap: (index) {},
      child: Scaffold(
        // The wrapper paints the pastel canvas; this page stays clear so the
        // glass cards pick it up.
        backgroundColor: Colors.transparent,
        body: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            children: [
              // 1. Ink hero: title, period summary and the date filter
              InkHero(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.page,
                  10,
                  AppSpace.page,
                  18,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(context, l10n),
                    const SizedBox(height: 14),

                    // 2. Date Filter Section
                    Entrance(
                      delay: const Duration(milliseconds: 180),
                      child: _buildFilterSection(l10n),
                    ),
                  ],
                ),
              ),

              // 3. History Entries List
              Expanded(
                child: Consumer<SalesHistoryProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading) {
                      return const _HistoryLoadingSkeleton();
                    }
                    if (provider.error != null) {
                      return _buildErrorState(context, provider.error!);
                    }

                    final entries = _buildHistoryEntries(provider.salesHistory);

                    if (entries.isEmpty) {
                      return _buildEmptyState(context, provider, l10n);
                    }

                    return RefreshIndicator(
                      color: AppColors.indigo,
                      backgroundColor: AppColors.surface,
                      onRefresh: _refreshSalesHistory,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        // The list runs under the glass dock.
                        padding: EdgeInsets.fromLTRB(
                          16,
                          14,
                          16,
                          MediaQuery.paddingOf(context).bottom + 20,
                        ),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          if (entry is BasketEntry) {
                            return _arrive(
                              index,
                              _buildBasketCard(entry, l10n),
                            );
                          } else if (entry is SingleSaleEntry) {
                            return _arrive(
                              index,
                              _buildSingleSaleCard(entry.sale, l10n),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Entrance(
          offset: const Offset(0, -12),
          child: Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.salesHistory,
                    maxLines: 1,
                    style: AppText.display(size: 25, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GlassIconButton(
                icon: Icons.info_outline_rounded,
                tooltip: 'Information',
                onTap: () => _showInfoDialog(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Entrance(
          delay: const Duration(milliseconds: 90),
          child: _buildPeriodSummary(l10n),
        ),
      ],
    );
  }

  /// What the selected period adds up to, read from the list already on
  /// screen: how many sales, the points that are validated and the points
  /// still waiting.
  Widget _buildPeriodSummary(AppLocalizations l10n) {
    return Consumer<SalesHistoryProvider>(
      builder: (context, provider, child) {
        final sales = provider.salesHistory;
        double validatedPoints = 0;
        double pendingPoints = 0;
        for (final sale in sales) {
          if (sale.status == 'approved') {
            validatedPoints += sale.pointsEarned;
          } else if (sale.status == 'pending') {
            pendingPoints += sale.pointsEarned;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedOpacity(
              duration: AppMotion.fast,
              opacity: provider.isLoading ? 0 : 1,
              child: Text(
                l10n.salesRecorded(sales.length),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(
                  size: 14,
                  weight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildHeroStat(
                    icon: Icons.check_circle_rounded,
                    iconColor: AppColors.mintBright,
                    label: 'Validé',
                    value: validatedPoints,
                    valueColor: AppColors.mintBright,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildHeroStat(
                    icon: Icons.schedule_rounded,
                    iconColor: AppColors.amber,
                    label: 'En attente',
                    value: pendingPoints,
                    valueColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeroStat({
    required IconData icon,
    required Color iconColor,
    required String label,
    required double value,
    required Color valueColor,
  }) {
    final muted = Colors.white.withValues(alpha: 0.78);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: iconColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.label(size: 12.5, color: muted, letterSpacing: 0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              CountUp(
                value: value,
                style: AppText.display(size: 30, color: valueColor),
              ),
              const SizedBox(width: 5),
              Text('pts', style: AppText.label(size: 14, color: muted)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, String errorMessage) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Centre in what is visible above the glass dock.
        final dock = MediaQuery.paddingOf(context).bottom;
        return SingleChildScrollView(
          padding: EdgeInsets.only(bottom: dock),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  (constraints.maxHeight - dock).clamp(0.0, double.infinity),
            ),
            child: EmptyState(
              icon: Icons.error_outline_rounded,
              tone: Tone.coral,
              title: errorMessage,
              actionLabel: 'Réessayer',
              onAction: _refreshSalesHistory,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    SalesHistoryProvider provider,
    AppLocalizations l10n,
  ) {
    final hasFilter = provider.startDate != null || provider.endDate != null;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return RefreshIndicator(
      color: AppColors.indigo,
      backgroundColor: AppColors.surface,
      onRefresh: _refreshSalesHistory,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Centre in what is visible above the glass dock.
          final dock = MediaQuery.paddingOf(context).bottom;
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(bottom: dock),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    (constraints.maxHeight - dock).clamp(0.0, double.infinity),
              ),
              child: EmptyState(
                icon: Icons.receipt_long_rounded,
                tone: Tone.peach,
                title: l10n.noSalesRecorded,
                message: hasFilter
                    ? 'Essayez d\'élargir ou de réinitialiser la période sélectionnée.'
                    : 'Vos ventes directes et paniers validés apparaîtront ici.',
                actionLabel: hasFilter ? l10n.clear : null,
                onAction: hasFilter
                    ? () {
                        final userId = authProvider.firebaseUser?.uid;
                        if (userId != null) {
                          provider.clearFilters();
                          provider.fetchSalesHistory(userId);
                        }
                      }
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  List<HistoryEntry> _buildHistoryEntries(List<Sale> rawSales) {
    final Map<String, List<Sale>> basketGroups = {};
    final List<Sale> directSales = [];

    for (final sale in rawSales) {
      if (sale.basketId != null && sale.basketId!.isNotEmpty) {
        basketGroups.putIfAbsent(sale.basketId!, () => []).add(sale);
      } else {
        directSales.add(sale);
      }
    }

    final List<HistoryEntry> entries = [];

    for (final sale in directSales) {
      entries.add(SingleSaleEntry(sale));
    }

    basketGroups.forEach((basketId, bSales) {
      bSales.sort((a, b) => b.saleDate.compareTo(a.saleDate));
      final latestDate = bSales.first.saleDate;
      final totalAmount =
          bSales.fold<double>(0.0, (sum, s) => sum + s.totalPrice);
      final totalQuantity =
          bSales.fold<int>(0, (sum, s) => sum + s.quantity);
      final totalPoints =
          bSales.fold<double>(0.0, (sum, s) => sum + s.pointsEarned);

      String overallStatus = 'approved';
      if (bSales.any((s) => s.status == 'pending')) {
        overallStatus = 'pending';
      } else if (bSales.every((s) => s.status == 'rejected')) {
        overallStatus = 'rejected';
      } else if (bSales.every((s) => s.status == 'cancelled')) {
        overallStatus = 'cancelled';
      }

      entries.add(
        BasketEntry(
          basketId: basketId,
          sales: bSales,
          basketDate: latestDate,
          totalAmount: totalAmount,
          totalQuantity: totalQuantity,
          totalPoints: totalPoints,
          status: overallStatus,
        ),
      );
    });

    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  Widget _buildBasketCard(BasketEntry entry, AppLocalizations l10n) {
    final productNames = entry.sales
        .map((s) => s.productNameSnapshot)
        .where((name) => name.trim().isNotEmpty)
        .toSet()
        .toList();
    final previewText = productNames.join(', ');
    final shortId = entry.basketId.length > 8
        ? entry.basketId.substring(0, 8)
        : entry.basketId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        onTap: () => _showBasketDetailsDialog(context, entry.basketId),
        semanticLabel: 'Panier #$shortId',
        padding: const EdgeInsets.all(14),
        radius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // When it happened + where it stands
            _buildCardTopLine(entry.basketDate, entry.status),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Basket Icon Badge
                const TintIcon(
                  icon: Icons.shopping_basket_rounded,
                  tone: Tone.peach,
                  size: 56,
                ),
                const SizedBox(width: 12),

                // Title + Preview
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('Panier', style: AppText.display(size: 17)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '#$shortId',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.label(size: 12.5),
                            ),
                          ),
                        ],
                      ),
                      if (previewText.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          previewText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(
                            size: 13,
                            color: AppColors.textMuted,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Points earned + basket total
                _buildAmounts(
                  points: entry.totalPoints,
                  showPoints: true,
                  price: entry.totalAmount,
                  showPrice: true,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Card Footer: Items + Details CTA
            Row(
              children: [
                Expanded(
                  child: _buildMetricPill(
                    icon: Icons.inventory_2_outlined,
                    label:
                        '${entry.totalQuantity} article${entry.totalQuantity > 1 ? 's' : ''}',
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Voir détails',
                  style: AppText.label(
                    size: 13,
                    weight: FontWeight.w700,
                    color: AppColors.indigo,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.indigo,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleSaleCard(Sale sale, AppLocalizations l10n) {
    final isPending = sale.status == 'pending';
    final hasBrand = sale.productBrandSnapshot != null &&
        sale.productBrandSnapshot!.trim().isNotEmpty;
    final qtyPrefix = Localizations.localeOf(context).languageCode == 'en' ? 'Qty' : 'Qté';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        padding: const EdgeInsets.all(14),
        radius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // When it happened + where it stands
            _buildCardTopLine(sale.saleDate, sale.status),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Thumbnail with Cached Network Loader
                FutureBuilder<String?>(
                  future: _getProductImage(sale.productId),
                  builder: (context, snapshot) {
                    final imageUrl = snapshot.data;
                    return Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSunken,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? AppNetworkImage(
                              imageUrl: imageUrl,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              memCacheWidth: 180,
                              borderRadius: BorderRadius.circular(16),
                              backgroundColor: AppColors.surfaceSunken,
                              placeholder: (context, url) =>
                                  const SizedBox(width: 56, height: 56),
                              errorIcon: Icons.shopping_bag_outlined,
                              errorIconColor: AppColors.textFaint,
                            )
                          : const Icon(
                              Icons.shopping_bag_rounded,
                              color: AppColors.peach,
                              size: 26,
                            ),
                    );
                  },
                ),
                const SizedBox(width: 12),

                // Product Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasBrand) ...[
                        Text(
                          sale.productBrandSnapshot!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.label(size: 12, letterSpacing: 0),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        sale.productNameSnapshot,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(
                          size: 15,
                          weight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildMetricPill(
                        icon: Icons.layers_outlined,
                        label: '$qtyPrefix: ${sale.quantity}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Points earned + amount
                _buildAmounts(
                  points: sale.pointsEarned,
                  showPoints: sale.pointsEarned > 0,
                  price: sale.totalPrice,
                  showPrice: sale.totalPrice > 0,
                ),
              ],
            ),

            // Attached Gift Operation Banner (Cached)
            FutureBuilder<_SaleGiftInfo?>(
              future: _getSaleGiftInfo(sale.id),
              builder: (context, snapshot) {
                final giftInfo = snapshot.data;
                if (giftInfo == null) return const SizedBox.shrink();

                return Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.amberTint,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.card_giftcard_rounded,
                        size: 16,
                        color: AppColors.amberDeep,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${giftInfo.title} (x${giftInfo.quantity})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.label(
                            size: 12.5,
                            weight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      if (giftInfo.operationId.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'ID Offre Cadeau: ${giftInfo.operationId}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.label(
                              size: 11,
                              weight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),

            // Pending sales can still be edited or deleted
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildCompactActionButton(
                      icon: Icons.edit_rounded,
                      label: 'Modifier',
                      tone: Tone.indigo,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ProductScreen(sale: sale),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildCompactActionButton(
                    icon: Icons.delete_outline_rounded,
                    tooltip: l10n.delete,
                    tone: Tone.coral,
                    onTap: () => _showDeleteConfirmationDialog(context, sale),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The line every history card opens with: when it happened, as a muted
  /// label, and where it stands.
  Widget _buildCardTopLine(DateTime date, String status) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _formatLocalizedDate(context, date, includeTime: true),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.label(size: 12.5),
          ),
        ),
        const SizedBox(width: 8),
        _buildStatusPill(status),
      ],
    );
  }

  /// Points earned as the figure that leads, the amount underneath.
  Widget _buildAmounts({
    required double points,
    required bool showPoints,
    required double price,
    required bool showPrice,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showPoints)
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '+${_formatPoints(points)}',
                style: AppText.display(size: 20, color: AppColors.mintDeep),
              ),
              const SizedBox(width: 3),
              Text(
                'pts',
                style: AppText.label(size: 12, color: AppColors.mintDeep),
              ),
            ],
          ),
        if (showPoints && showPrice) const SizedBox(height: 5),
        if (showPrice)
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                price.toStringAsFixed(3),
                style: AppText.display(size: 14, weight: FontWeight.w600),
              ),
              const SizedBox(width: 3),
              Text('TND', style: AppText.label(size: 10.5)),
            ],
          ),
      ],
    );
  }

  /// A quiet metric: small icon, muted label.
  Widget _buildMetricPill({
    required IconData icon,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.label(size: 12.5),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactActionButton({
    required IconData icon,
    String? label,
    String? tooltip,
    required Tone tone,
    required VoidCallback onTap,
  }) {
    if (label != null) {
      return SecondaryButton(
        label: label,
        icon: icon,
        tone: tone,
        height: 44,
        onPressed: onTap,
      );
    }

    final button = Pressable(
      onTap: onTap,
      pressedScale: 0.9,
      semanticLabel: tooltip,
      child: Container(
        width: 52,
        height: 44,
        decoration: BoxDecoration(
          color: tone.tint,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Icon(icon, size: 21, color: tone.deep),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }

  Widget _buildStatusPill(String status) {
    Tone tone = Tone.amber;
    IconData icon = Icons.schedule_rounded;
    String label = 'En attente';

    if (status == 'approved') {
      tone = Tone.mint;
      icon = Icons.check_circle_rounded;
      label = 'Validé';
    } else if (status == 'rejected') {
      tone = Tone.coral;
      icon = Icons.cancel_rounded;
      label = 'Rejeté';
    } else if (status == 'cancelled') {
      tone = _neutralTone;
      icon = Icons.remove_circle_outline_rounded;
      label = 'Annulé';
    }

    return TonePill(label: label, tone: tone, icon: icon);
  }

  Widget _buildFilterSection(AppLocalizations l10n) {
    return Consumer<SalesHistoryProvider>(
      builder: (context, provider, child) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final hasActiveFilter =
            provider.startDate != null || provider.endDate != null;

        // Dark glass on the aurora: the one frosted pane of the hero.
        return SoftCard(
          style: GlassStyle.dark,
          blur: Glass.frost,
          radius: AppRadii.md,
          shadow: false,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tappable Header Row (allows collapsing filter card while scrolling)
              Pressable(
                pressedScale: 0.98,
                onTap: () {
                  setState(() {
                    _isFilterExpanded = !_isFilterExpanded;
                  });
                },
                child: SizedBox(
                  height: 48,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 10, 0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.tune_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  l10n.dateFilter,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.body(
                                    size: 14.5,
                                    weight: FontWeight.w600,
                                    color: Colors.white,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              if (hasActiveFilter) ...[
                                const SizedBox(width: 8),
                                Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 190,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.pill,
                                    ),
                                  ),
                                  child: Text(
                                    !_isFilterExpanded
                                        ? _buildCompactFilterSummary(
                                            context,
                                            provider.startDate,
                                            provider.endDate,
                                          )
                                        : 'Actif',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.label(
                                      size: 11.5,
                                      weight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Icon(
                          _isFilterExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Collapsible Filter Controls (Expanded by default)
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                sizeCurve: Curves.easeOutCubic,
                crossFadeState: _isFilterExpanded
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateButton(
                              context: context,
                              label: l10n.start.replaceAll(':', '').trim(),
                              date: provider.startDate,
                              onPressed: () => _selectDate(context, true),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.78),
                            ),
                          ),
                          Expanded(
                            child: _buildDateButton(
                              context: context,
                              label: l10n.end.replaceAll(':', '').trim(),
                              date: provider.endDate,
                              onPressed: () => _selectDate(context, false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: SecondaryButton(
                              label: l10n.clear,
                              icon: Icons.restart_alt_rounded,
                              onDark: true,
                              height: 44,
                              onPressed: () {
                                final userId = authProvider.firebaseUser?.uid;
                                if (userId != null) {
                                  provider.clearFilters();
                                  provider.fetchSalesHistory(userId);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: PrimaryButton.mint(
                              label: l10n.filter,
                              icon: Icons.search_rounded,
                              height: 44,
                              onPressed: () {
                                final userId = authProvider.firebaseUser?.uid;
                                if (userId != null) {
                                  provider.fetchSalesHistory(userId);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                secondChild: const SizedBox(width: double.infinity),
              ),
            ],
          ),
        );
      },
    );
  }

  String _buildCompactFilterSummary(
    BuildContext context,
    DateTime? start,
    DateTime? end,
  ) {
    final startStr = start != null ? _formatLocalizedDate(context, start) : '...';
    final endStr = end != null ? _formatLocalizedDate(context, end) : '...';
    return '$startStr → $endStr';
  }

  Widget _buildDateButton({
    required BuildContext context,
    required String label,
    DateTime? date,
    required VoidCallback onPressed,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final isSelected = date != null;
    final soft = Colors.white.withValues(alpha: 0.78);

    // A field on dark glass: translucent fill, mint rim once a date is set.
    return Pressable(
      onTap: onPressed,
      pressedScale: 0.97,
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: isSelected ? 0.18 : 0.10),
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(
            color: isSelected
                ? AppColors.mintBright.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.22),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label(size: 11.5, color: soft, letterSpacing: 0),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  color: isSelected ? AppColors.mintBright : soft,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isSelected ? _formatLocalizedDate(context, date) : l10n.select,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(
                      size: 13.5,
                      weight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : soft,
                      height: 1.2,
                    ),
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

// ---------------------------------------------------------------------------
// Shimmering skeleton, shaped like the history cards, while fetching sales
// ---------------------------------------------------------------------------
class _HistoryLoadingSkeleton extends StatelessWidget {
  const _HistoryLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        MediaQuery.paddingOf(context).bottom + 20,
      ),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SoftCard(
            padding: const EdgeInsets.all(14),
            radius: 24,
            child: Shimmer(
              child: Column(
                children: [
                  // Date + status
                  const Row(
                    children: [
                      SkeletonBox(width: 124, height: 12, radius: 6),
                      Spacer(),
                      SkeletonBox(
                        width: 84,
                        height: 24,
                        radius: AppRadii.pill,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SkeletonBox(width: 56, height: 56, radius: 16),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SkeletonBox(width: 72, height: 11, radius: 6),
                            const SizedBox(height: 8),
                            FractionallySizedBox(
                              widthFactor: index.isEven ? 0.92 : 0.7,
                              child: const SkeletonBox(height: 15, radius: 6),
                            ),
                            const SizedBox(height: 10),
                            const SkeletonBox(width: 58, height: 11, radius: 6),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          SkeletonBox(width: 58, height: 20, radius: 6),
                          SizedBox(height: 8),
                          SkeletonBox(width: 66, height: 12, radius: 6),
                        ],
                      ),
                    ],
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

// ---------------------------------------------------------------------------
// Pop-up Sheet: Details du Panier et liste de ses ventes
// ---------------------------------------------------------------------------
class _BasketDetailsSheet extends StatefulWidget {
  final String basketId;
  final BasketService basketService;
  final Future<String?> Function(String productId) getProductImage;

  const _BasketDetailsSheet({
    required this.basketId,
    required this.basketService,
    required this.getProductImage,
  });

  @override
  State<_BasketDetailsSheet> createState() => _BasketDetailsSheetState();
}

class _BasketDetailsSheetState extends State<_BasketDetailsSheet> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchData();
  }

  Future<Map<String, dynamic>> _fetchData() async {
    final results = await Future.wait([
      widget.basketService.getBasketById(widget.basketId),
      widget.basketService.getSalesForBasket(widget.basketId),
    ]);
    return {
      'basket': results[0] as Basket?,
      'sales': results[1] as List<Sale>,
    };
  }

  String _formatPoints(double points) {
    if (points == points.roundToDouble()) {
      return points.toInt().toString();
    }
    return points.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return GlassSheet(
      padding: EdgeInsets.zero,
      child: ConstrainedBox(
        // Same overall height as before: 88% of the screen, handle and
        // bottom inset included.
        constraints: BoxConstraints(
          maxHeight: media.size.height * 0.88 - media.padding.bottom - 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CapsuleLoader());
                  }

                  if (snapshot.hasError || !snapshot.hasData) {
                    return const EmptyState(
                      icon: Icons.error_outline_rounded,
                      tone: Tone.coral,
                      title: 'Erreur de chargement du panier',
                    );
                  }

                  final basket = snapshot.data!['basket'] as Basket?;
                  final sales = (snapshot.data!['sales'] as List<Sale>?) ?? [];

                  if (basket == null && sales.isEmpty) {
                    return const EmptyState(
                      icon: Icons.shopping_basket_outlined,
                      tone: Tone.peach,
                      title: 'Panier introuvable ou supprimé.',
                    );
                  }

                  final totalAmount = basket?.totalAmount ??
                      sales.fold<double>(0.0, (sum, s) => sum + s.totalPrice);
                  final totalItems = basket?.itemsCount ??
                      sales.fold<int>(0, (sum, s) => sum + s.quantity);
                  final totalPoints = basket?.totalPoints ??
                      sales.fold<double>(0.0, (sum, s) => sum + s.pointsEarned);

                  final status = basket?.status ?? 'closed';
                  final isClosed = status == 'closed';
                  final isOpen = status == 'open';

                  final date = basket?.closedAt ??
                      basket?.openedAt ??
                      (sales.isNotEmpty ? sales.first.saleDate : DateTime.now());
                  final pharmacyName = basket?.pharmacyNameSnapshot ??
                      (sales.isNotEmpty ? sales.first.pharmacyId : '');
                  final pointOfSale = basket?.pointOfSaleSnapshot;
                  final shortId = widget.basketId.length > 8
                      ? widget.basketId.substring(0, 8)
                      : widget.basketId;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    children: [
                      // Header Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const TintIcon(
                            icon: Icons.shopping_basket_rounded,
                            tone: Tone.peach,
                            size: 52,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Panier #$shortId',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.display(size: 20),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    TonePill(
                                      label: isClosed
                                          ? 'Clôturé'
                                          : isOpen
                                              ? 'En cours'
                                              : 'Annulé',
                                      tone: isClosed
                                          ? Tone.mint
                                          : isOpen
                                              ? Tone.amber
                                              : _neutralTone,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.schedule_rounded,
                                      size: 14,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        DateFormat('dd/MM/yyyy à HH:mm').format(date),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.label(size: 12.5),
                                      ),
                                    ),
                                  ],
                                ),
                                if (pharmacyName.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.storefront_outlined,
                                        size: 14,
                                        color: AppColors.textMuted,
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          pharmacyName +
                                              (pointOfSale != null &&
                                                      pointOfSale.isNotEmpty
                                                  ? ' • $pointOfSale'
                                                  : ''),
                                          overflow: TextOverflow.ellipsis,
                                          style: AppText.label(size: 12.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // KPI Summary Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildKpiBox(
                              label: 'Total Panier',
                              value: totalAmount.toStringAsFixed(3),
                              unit: 'TND',
                              tone: Tone.peach,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildKpiBox(
                              label: 'Articles',
                              value: '$totalItems',
                              unit: basket?.items != null
                                  ? '${basket!.items.length} réf.'
                                  : 'produits',
                              tone: Tone.indigo,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildKpiBox(
                              label: 'Points',
                              value: '+${_formatPoints(totalPoints)}',
                              unit: 'pts',
                              tone: Tone.mint,
                              valueColor: AppColors.mintDeep,
                            ),
                          ),
                        ],
                      ),

                      // Gift Banner if available
                      if (basket != null &&
                          basket.hasGift &&
                          basket.giftsGiven.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.amberTint,
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.card_giftcard_rounded,
                                  color: AppColors.amberDeep,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Cadeau offert : ${basket.giftsGiven.map((g) => '${g['title'] ?? g['giftTitle'] ?? 'Cadeau'} (x${g['quantity'] ?? 1})').join(', ')}',
                                  style: AppText.body(
                                    size: 13.5,
                                    weight: FontWeight.w700,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 22),

                      // Section: Articles in this basket
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Articles de ce panier',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.display(size: 17),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TonePill(
                            label:
                                '${sales.isNotEmpty ? sales.length : (basket?.items.length ?? 0)}',
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Articles list
                      if (sales.isNotEmpty) ...[
                        ...sales.map(_buildSaleItemTile),
                      ] else if (basket != null && basket.items.isNotEmpty) ...[
                        ...basket.items.map(_buildBasketItemTile),
                      ] else ...[
                        const EmptyState(
                          icon: Icons.inventory_2_outlined,
                          tone: Tone.peach,
                          title: 'Aucun article répertorié.',
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),

            // Sticky Bottom Close Action
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
              child: SecondaryButton(
                label: 'Fermer',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiBox({
    required String label,
    required String value,
    required String unit,
    required Tone tone,
    Color valueColor = AppColors.text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: tone.tint,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.label(size: 11.5, letterSpacing: 0),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppText.display(size: 19, color: valueColor),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            unit,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.label(
              size: 11,
              weight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleItemTile(Sale sale) {
    final hasBrand = sale.productBrandSnapshot != null &&
        sale.productBrandSnapshot!.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        padding: const EdgeInsets.all(12),
        radius: AppRadii.md,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FutureBuilder<String?>(
              future: widget.getProductImage(sale.productId),
              builder: (context, snap) {
                if (snap.hasData && snap.data != null && snap.data!.isNotEmpty) {
                  return _buildThumbnail(snap.data!);
                }
                return _defaultImageWidget();
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasBrand) ...[
                    Text(
                      sale.productBrandSnapshot!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.label(size: 11.5, letterSpacing: 0),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    sale.productNameSnapshot,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(
                      size: 14,
                      weight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Qté: ${sale.quantity}',
                        style: AppText.label(size: 12.5),
                      ),
                      _buildStatusBadge(sale.status),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildLineAmounts(
              points: sale.pointsEarned,
              amount: sale.totalPrice,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasketItemTile(BasketItem item) {
    final directImageUrl = item.imageUrl?.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        padding: const EdgeInsets.all(12),
        radius: AppRadii.md,
        child: Row(
          children: [
            if (directImageUrl.isNotEmpty)
              _buildThumbnail(directImageUrl)
            else
              FutureBuilder<String?>(
                future: widget.getProductImage(item.productId),
                builder: (context, snap) {
                  if (snap.hasData &&
                      snap.data != null &&
                      snap.data!.isNotEmpty) {
                    return _buildThumbnail(snap.data!);
                  }
                  return _defaultImageWidget();
                },
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.marque != null && item.marque!.trim().isNotEmpty) ...[
                    Text(
                      item.marque!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.label(size: 11.5, letterSpacing: 0),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(
                      size: 14,
                      weight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Qté: ${item.quantity}',
                    style: AppText.label(size: 12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildLineAmounts(
              points: item.pointsEarned,
              amount: item.lineTotal,
            ),
          ],
        ),
      ),
    );
  }

  /// Points earned as the figure that leads, the line amount underneath.
  Widget _buildLineAmounts({required double points, required double amount}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '+${_formatPoints(points)}',
              style: AppText.display(size: 17, color: AppColors.mintDeep),
            ),
            const SizedBox(width: 3),
            Text(
              'pts',
              style: AppText.label(size: 11.5, color: AppColors.mintDeep),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              amount.toStringAsFixed(3),
              style: AppText.display(size: 13.5, weight: FontWeight.w600),
            ),
            const SizedBox(width: 3),
            Text('TND', style: AppText.label(size: 10.5)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Tone tone = Tone.amber;
    String label = 'En attente';

    if (status == 'approved') {
      tone = Tone.mint;
      label = 'Validé';
    } else if (status == 'rejected') {
      tone = Tone.coral;
      label = 'Rejeté';
    } else if (status == 'cancelled') {
      tone = _neutralTone;
      label = 'Annulé';
    }

    return TonePill(label: label, tone: tone);
  }

  Widget _buildThumbnail(String imageUrl) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(14),
      ),
      child: AppNetworkImage(
        imageUrl: imageUrl,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        memCacheWidth: 160,
        borderRadius: BorderRadius.circular(14),
        placeholder: (context, url) => const SizedBox(width: 50, height: 50),
      ),
    );
  }

  Widget _defaultImageWidget() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(
        Icons.shopping_bag_outlined,
        color: AppColors.textFaint,
        size: 22,
      ),
    );
  }
}
