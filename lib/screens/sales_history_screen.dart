import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/controllers/sales_history_provider.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';
import 'package:novopharma/models/basket.dart';
import 'package:novopharma/models/basket_item.dart';
import 'package:novopharma/models/gift.dart';
import 'package:novopharma/models/sale.dart';
import 'package:novopharma/screens/product_screen.dart';
import 'package:novopharma/services/basket_service.dart';
import 'package:novopharma/services/gift_service.dart';
import 'package:novopharma/services/product_service.dart';
import 'package:novopharma/theme.dart';
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
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: LightModeColors.lightPrimary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: LightModeColors.dashboardTextPrimary,
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
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
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFDC2626),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.confirmDeletion,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: LightModeColors.dashboardTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            l10n.confirmDeletionMessage,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.5,
              color: LightModeColors.dashboardTextSecondary,
            ),
          ),
          actions: <Widget>[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: LightModeColors.dashboardTextSecondary,
                      side: const BorderSide(color: LightModeColors.cardBorder),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      l10n.cancel,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Provider.of<SalesHistoryProvider>(
                        context,
                        listen: false,
                      ).deleteSale(sale);
                      Navigator.of(ctx).pop();
                    },
                    child: Text(
                      l10n.delete,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: LightModeColors.novoPharmaLightBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: LightModeColors.lightPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: LightModeColors.dashboardTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Après validation, vos points sont automatiquement ajoutés à votre solde de points utilisables et peuvent être échangés en crédits Pluxee.',
            style: TextStyle(
              fontSize: 14.5,
              height: 1.55,
              color: LightModeColors.dashboardTextSecondary,
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: LightModeColors.lightPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Fermer',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        );
      },
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
        backgroundColor: LightModeColors.lightBackground,
        body: SafeArea(
          child: Column(
            children: [
              // 1. Modern Header
              _buildHeader(context, l10n),

              // 2. Date Filter Section
              _buildFilterSection(l10n),

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
                      color: LightModeColors.lightPrimary,
                      backgroundColor: Colors.white,
                      onRefresh: _refreshSalesHistory,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 108),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          if (entry is BasketEntry) {
                            return _buildBasketCard(entry, l10n);
                          } else if (entry is SingleSaleEntry) {
                            return _buildSingleSaleCard(entry.sale, l10n);
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: LightModeColors.lightSurface,
        border: Border(
          bottom: BorderSide(color: LightModeColors.cardBorder, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  LightModeColors.lightPrimary,
                  LightModeColors.lightTertiary,
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: LightModeColors.lightPrimary.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: LightModeColors.lightOnPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              l10n.salesHistory,
              style: const TextStyle(
                color: LightModeColors.dashboardTextPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: LightModeColors.novoPharmaLightBlue.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _showInfoDialog(context),
              borderRadius: BorderRadius.circular(12),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.info_outline_rounded,
                  color: LightModeColors.lightPrimary,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFDC2626),
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: LightModeColors.dashboardTextPrimary,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _refreshSalesHistory,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Réessayer'),
              style: OutlinedButton.styleFrom(
                foregroundColor: LightModeColors.lightPrimary,
                side: const BorderSide(color: LightModeColors.lightPrimary),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
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
      color: LightModeColors.lightPrimary,
      backgroundColor: Colors.white,
      onRefresh: _refreshSalesHistory,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: LightModeColors.novoPharmaLightBlue.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.receipt_long_outlined,
                          size: 36,
                          color: LightModeColors.lightPrimary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        l10n.noSalesRecorded,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: LightModeColors.dashboardTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hasFilter
                            ? 'Essayez d\'élargir ou de réinitialiser la période sélectionnée.'
                            : 'Vos ventes directes et paniers validés apparaîtront ici.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color: LightModeColors.dashboardTextSecondary,
                        ),
                      ),
                      if (hasFilter) ...[
                        const SizedBox(height: 18),
                        TextButton.icon(
                          onPressed: () {
                            final userId = authProvider.firebaseUser?.uid;
                            if (userId != null) {
                              provider.clearFilters();
                              provider.fetchSalesHistory(userId);
                            }
                          },
                          icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                          label: Text(l10n.clear),
                          style: TextButton.styleFrom(
                            foregroundColor: LightModeColors.lightPrimary,
                            backgroundColor:
                                LightModeColors.novoPharmaLightBlue.withValues(alpha: 0.6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: LightModeColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: LightModeColors.cardBorder,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _showBasketDetailsDialog(context, entry.basketId),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basket Icon Badge
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFECFDF5),
                            Color(0xFFD1FAE5),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: const Color(0xFFA7F3D0),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.shopping_basket_rounded,
                        color: Color(0xFF059669),
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Title + Preview + Chips
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Panier',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15.5,
                                  color: LightModeColors.dashboardTextPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Text(
                                    '#$shortId',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF64748B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (previewText.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              previewText,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: LightModeColors.dashboardTextSecondary,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildMetricPill(
                                  icon: Icons.inventory_2_outlined,
                                  label:
                                      '${entry.totalQuantity} article${entry.totalQuantity > 1 ? 's' : ''}',
                                  bgColor: const Color(0xFFEFF6FF),
                                  borderColor: const Color(0xFFBFDBFE),
                                  fgColor: const Color(0xFF1D4ED8),
                                ),
                                const SizedBox(width: 6),
                                _buildMetricPill(
                                  icon: Icons.stars_rounded,
                                  label: '+${_formatPoints(entry.totalPoints)} pts',
                                  bgColor: const Color(0xFFFFFBEB),
                                  borderColor: const Color(0xFFFDE68A),
                                  fgColor: const Color(0xFFB45309),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Right Price & Status
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              entry.totalAmount.toStringAsFixed(3),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: LightModeColors.dashboardTextPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Text(
                              'TND',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: LightModeColors.dashboardTextSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildStatusPill(entry.status),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                Container(
                  height: 1,
                  color: LightModeColors.lightSurfaceVariant,
                ),
                const SizedBox(height: 8),

                // Card Footer: Date + Details CTA
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 13.5,
                      color: LightModeColors.dashboardTextTertiary,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        _formatLocalizedDate(
                          context,
                          entry.basketDate,
                          includeTime: true,
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: LightModeColors.dashboardTextSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Text(
                      'Voir détails',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 17,
                      color: Color(0xFF059669),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSingleSaleCard(Sale sale, AppLocalizations l10n) {
    final isPending = sale.status == 'pending';
    final hasBrand = sale.productBrandSnapshot != null &&
        sale.productBrandSnapshot!.trim().isNotEmpty;
    final qtyPrefix = Localizations.localeOf(context).languageCode == 'en' ? 'Qty' : 'Qté';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: LightModeColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: LightModeColors.cardBorder,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                        color: LightModeColors.lightBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: LightModeColors.cardBorder,
                          width: 1,
                        ),
                      ),
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? AppNetworkImage(
                              imageUrl: imageUrl,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              memCacheWidth: 180,
                              borderRadius: BorderRadius.circular(13),
                              backgroundColor: LightModeColors.lightBackground,
                              errorIcon: Icons.shopping_bag_outlined,
                              errorIconColor: LightModeColors.lightPrimary
                                  .withValues(alpha: 0.45),
                            )
                          : Icon(
                              Icons.shopping_bag_rounded,
                              color: LightModeColors.lightPrimary
                                  .withValues(alpha: 0.7),
                              size: 26,
                            ),
                    );
                  },
                ),
                const SizedBox(width: 12),

                // Product Info & Chips
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasBrand) ...[
                        Text(
                          sale.productBrandSnapshot!.trim().toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: LightModeColors.lightPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        sale.productNameSnapshot,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: LightModeColors.dashboardTextPrimary,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildMetricPill(
                              icon: Icons.layers_outlined,
                              label: '$qtyPrefix: ${sale.quantity}',
                              bgColor: const Color(0xFFEFF6FF),
                              borderColor: const Color(0xFFBFDBFE),
                              fgColor: const Color(0xFF1D4ED8),
                            ),
                            if (sale.pointsEarned > 0) ...[
                              const SizedBox(width: 6),
                              _buildMetricPill(
                                icon: Icons.stars_rounded,
                                label: '+${_formatPoints(sale.pointsEarned)} pts',
                                bgColor: const Color(0xFFFFFBEB),
                                borderColor: const Color(0xFFFDE68A),
                                fgColor: const Color(0xFFB45309),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Right Price & Status Badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (sale.totalPrice > 0) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            sale.totalPrice.toStringAsFixed(3),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: LightModeColors.dashboardTextPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Text(
                            'TND',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: LightModeColors.dashboardTextSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    _buildStatusPill(sale.status),
                  ],
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
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: LightModeColors.novoPharmaBlue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          LightModeColors.novoPharmaBlue.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.card_giftcard_rounded,
                        size: 15,
                        color: LightModeColors.novoPharmaBlue,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          '${giftInfo.title} (x${giftInfo.quantity})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: LightModeColors.novoPharmaBlue,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (giftInfo.operationId.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'ID Offre Cadeau: ${giftInfo.operationId}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: LightModeColors.dashboardTextSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 10),
            Container(
              height: 1,
              color: LightModeColors.lightSurfaceVariant,
            ),
            const SizedBox(height: 8),

            // Footer Row: Date + Pending Edit/Delete Actions
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 13,
                  color: LightModeColors.dashboardTextTertiary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _formatLocalizedDate(
                      context,
                      sale.saleDate,
                      includeTime: true,
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: LightModeColors.dashboardTextSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (isPending) ...[
                  _buildCompactActionButton(
                    icon: Icons.edit_rounded,
                    label: 'Modifier',
                    bgColor: const Color(0xFFFFFBEB),
                    borderColor: const Color(0xFFFDE68A),
                    fgColor: const Color(0xFFB45309),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ProductScreen(sale: sale),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildCompactActionButton(
                    icon: Icons.delete_outline_rounded,
                    bgColor: const Color(0xFFFEF2F2),
                    borderColor: const Color(0xFFFECACA),
                    fgColor: const Color(0xFFDC2626),
                    onTap: () => _showDeleteConfirmationDialog(context, sale),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricPill({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color borderColor,
    required Color fgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11.5, color: fgColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fgColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactActionButton({
    required IconData icon,
    String? label,
    required Color bgColor,
    required Color borderColor,
    required Color fgColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: label != null ? 10 : 8,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fgColor),
              if (label != null) ...[
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: fgColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    Color bg = const Color(0xFFFFFBEB);
    Color border = const Color(0xFFFDE68A);
    Color fg = const Color(0xFFB45309);
    IconData icon = Icons.schedule_rounded;
    String label = 'En attente';

    if (status == 'approved') {
      bg = const Color(0xFFECFDF5);
      border = const Color(0xFFA7F3D0);
      fg = const Color(0xFF047857);
      icon = Icons.check_circle_rounded;
      label = 'Validé';
    } else if (status == 'rejected') {
      bg = const Color(0xFFFEF2F2);
      border = const Color(0xFFFECACA);
      fg = const Color(0xFFB91C1C);
      icon = Icons.cancel_rounded;
      label = 'Rejeté';
    } else if (status == 'cancelled') {
      bg = const Color(0xFFF1F5F9);
      border = const Color(0xFFE2E8F0);
      fg = const Color(0xFF475569);
      icon = Icons.remove_circle_outline_rounded;
      label = 'Annulé';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11.5, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(AppLocalizations l10n) {
    return Consumer<SalesHistoryProvider>(
      builder: (context, provider, child) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final hasActiveFilter =
            provider.startDate != null || provider.endDate != null;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          decoration: BoxDecoration(
            color: LightModeColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasActiveFilter
                  ? LightModeColors.lightPrimary.withValues(alpha: 0.3)
                  : LightModeColors.cardBorder,
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x060F172A),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tappable Header Row (allows collapsing filter card while scrolling)
              InkWell(
                onTap: () {
                  setState(() {
                    _isFilterExpanded = !_isFilterExpanded;
                  });
                },
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(16),
                  bottom: Radius.circular(_isFilterExpanded ? 0 : 16),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 9, 12, 9),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5.5),
                        decoration: BoxDecoration(
                          color: LightModeColors.novoPharmaLightBlue
                              .withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: LightModeColors.lightPrimary,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                l10n.dateFilter,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: LightModeColors.dashboardTextPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasActiveFilter) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: LightModeColors.novoPharmaLightBlue,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  !_isFilterExpanded
                                      ? _buildCompactFilterSummary(
                                          context,
                                          provider.startDate,
                                          provider.endDate,
                                        )
                                      : 'Actif',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: LightModeColors.lightPrimary,
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
                        color: LightModeColors.dashboardTextSecondary,
                        size: 20,
                      ),
                    ],
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
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
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
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 5),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: LightModeColors.dashboardTextTertiary,
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
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.restart_alt_rounded, size: 15),
                            label: Text(
                              l10n.clear,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: hasActiveFilter
                                  ? const Color(0xFFDC2626)
                                  : LightModeColors.dashboardTextTertiary,
                              backgroundColor: hasActiveFilter
                                  ? const Color(0xFFFEF2F2)
                                  : Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                            onPressed: () {
                              final userId = authProvider.firebaseUser?.uid;
                              if (userId != null) {
                                provider.clearFilters();
                                provider.fetchSalesHistory(userId);
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.search_rounded, size: 15),
                            label: Text(
                              l10n.filter,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: LightModeColors.lightPrimary,
                              foregroundColor: LightModeColors.lightOnPrimary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                            onPressed: () {
                              final userId = authProvider.firebaseUser?.uid;
                              if (userId != null) {
                                provider.fetchSalesHistory(userId);
                              }
                            },
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

    return Material(
      color: isSelected
          ? LightModeColors.novoPharmaLightBlue.withValues(alpha: 0.35)
          : LightModeColors.lightBackground,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: isSelected
                  ? LightModeColors.lightPrimary.withValues(alpha: 0.45)
                  : LightModeColors.cardBorder,
              width: 1.1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? LightModeColors.lightPrimary
                      : LightModeColors.dashboardTextSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    color: isSelected
                        ? LightModeColors.lightPrimary
                        : LightModeColors.dashboardTextTertiary,
                    size: 13,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      isSelected ? _formatLocalizedDate(context, date) : l10n.select,
                      style: TextStyle(
                        color: isSelected
                            ? LightModeColors.dashboardTextPrimary
                            : LightModeColors.dashboardTextTertiary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 12.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Smooth pulsing skeleton loader while fetching sales history
// ---------------------------------------------------------------------------
class _HistoryLoadingSkeleton extends StatefulWidget {
  const _HistoryLoadingSkeleton();

  @override
  State<_HistoryLoadingSkeleton> createState() =>
      _HistoryLoadingSkeletonState();
}

class _HistoryLoadingSkeletonState extends State<_HistoryLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final opacity = 0.4 + (_controller.value * 0.45);
        return Opacity(
          opacity: opacity,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: LightModeColors.cardBorder),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 14,
                                width: 150,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 11,
                                width: 100,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Container(
                                    height: 20,
                                    width: 68,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    height: 20,
                                    width: 58,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              height: 15,
                              width: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              height: 20,
                              width: 62,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 11,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              );
            },
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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(
                        color: Color(0xFF059669),
                      ),
                    ),
                  );
                }

                if (snapshot.hasError || !snapshot.hasData) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFEF2F2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.error_outline_rounded,
                              size: 36,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Erreur de chargement du panier',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: LightModeColors.dashboardTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final basket = snapshot.data!['basket'] as Basket?;
                final sales = (snapshot.data!['sales'] as List<Sale>?) ?? [];

                if (basket == null && sales.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Panier introuvable ou supprimé.',
                        style: TextStyle(
                          color: LightModeColors.dashboardTextSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    // Header Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFECFDF5),
                                Color(0xFFD1FAE5),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: const Icon(
                            Icons.shopping_basket_rounded,
                            color: Color(0xFF059669),
                            size: 26,
                          ),
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
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: LightModeColors
                                            .dashboardTextPrimary,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isClosed
                                          ? const Color(0xFFECFDF5)
                                          : isOpen
                                              ? const Color(0xFFFFFBEB)
                                              : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isClosed
                                            ? const Color(0xFFA7F3D0)
                                            : isOpen
                                                ? const Color(0xFFFDE68A)
                                                : const Color(0xFFE2E8F0),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      isClosed
                                          ? 'Clôturé'
                                          : isOpen
                                              ? 'En cours'
                                              : 'Annulé',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isClosed
                                            ? const Color(0xFF047857)
                                            : isOpen
                                                ? const Color(0xFFB45309)
                                                : const Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.schedule_rounded,
                                    size: 13,
                                    color: LightModeColors.dashboardTextTertiary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat('dd/MM/yyyy à HH:mm').format(date),
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      color: LightModeColors
                                          .dashboardTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              if (pharmacyName.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.storefront_outlined,
                                      size: 13.5,
                                      color:
                                          LightModeColors.dashboardTextTertiary,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        pharmacyName +
                                            (pointOfSale != null &&
                                                    pointOfSale.isNotEmpty
                                                ? ' • $pointOfSale'
                                                : ''),
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: LightModeColors
                                              .dashboardTextSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
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
                            bgColor: const Color(0xFFECFDF5),
                            borderColor: const Color(0xFFA7F3D0),
                            accentColor: const Color(0xFF059669),
                            valueColor: const Color(0xFF065F46),
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
                            bgColor: const Color(0xFFEFF6FF),
                            borderColor: const Color(0xFFBFDBFE),
                            accentColor: const Color(0xFF2563EB),
                            valueColor: const Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildKpiBox(
                            label: 'Points',
                            value: '+${_formatPoints(totalPoints)}',
                            unit: 'pts',
                            bgColor: const Color(0xFFFFFBEB),
                            borderColor: const Color(0xFFFDE68A),
                            accentColor: const Color(0xFFD97706),
                            valueColor: const Color(0xFF92400E),
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
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFFFBEB),
                              Color(0xFFFEF3C7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFCD34D)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.card_giftcard_rounded,
                                color: Color(0xFFD97706),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Cadeau offert : ${basket.giftsGiven.map((g) => '${g['title'] ?? g['giftTitle'] ?? 'Cadeau'} (x${g['quantity'] ?? 1})').join(', ')}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF92400E),
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Section: Articles in this basket
                    Row(
                      children: [
                        const Text(
                          'Articles de ce panier',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: LightModeColors.dashboardTextPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: LightModeColors.novoPharmaLightBlue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${sales.isNotEmpty ? sales.length : (basket?.items.length ?? 0)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: LightModeColors.lightPrimary,
                            ),
                          ),
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
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'Aucun article répertorié.',
                            style: TextStyle(
                              color: LightModeColors.dashboardTextSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),

          // Sticky Bottom Close Action
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: LightModeColors.cardBorder),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: LightModeColors.dashboardTextPrimary,
                    side: const BorderSide(color: LightModeColors.cardBorder),
                    backgroundColor: LightModeColors.lightBackground,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Fermer',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiBox({
    required String label,
    required String value,
    required String unit,
    required Color bgColor,
    required Color borderColor,
    required Color accentColor,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: accentColor,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: valueColor,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            unit,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleItemTile(Sale sale) {
    final hasBrand = sale.productBrandSnapshot != null &&
        sale.productBrandSnapshot!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LightModeColors.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FutureBuilder<String?>(
            future: widget.getProductImage(sale.productId),
            builder: (context, snap) {
              if (snap.hasData && snap.data != null && snap.data!.isNotEmpty) {
                return Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: LightModeColors.cardBorder),
                  ),
                  child: AppNetworkImage(
                    imageUrl: snap.data!,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    memCacheWidth: 160,
                    borderRadius: BorderRadius.circular(11),
                  ),
                );
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
                    sale.productBrandSnapshot!.trim().toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: LightModeColors.lightPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                ],
                Text(
                  sale.productNameSnapshot,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: LightModeColors.dashboardTextPrimary,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Text(
                        'Qté: ${sale.quantity}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Text(
                        '+${_formatPoints(sale.pointsEarned)} pts',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    sale.totalPrice.toStringAsFixed(3),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF065F46),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Text(
                    'TND',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: LightModeColors.dashboardTextSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _buildStatusBadge(sale.status),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBasketItemTile(BasketItem item) {
    final directImageUrl = item.imageUrl?.trim() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LightModeColors.cardBorder),
      ),
      child: Row(
        children: [
          if (directImageUrl.isNotEmpty)
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: LightModeColors.cardBorder),
              ),
              child: AppNetworkImage(
                imageUrl: directImageUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                memCacheWidth: 160,
                borderRadius: BorderRadius.circular(11),
              ),
            )
          else
            FutureBuilder<String?>(
              future: widget.getProductImage(item.productId),
              builder: (context, snap) {
                if (snap.hasData &&
                    snap.data != null &&
                    snap.data!.isNotEmpty) {
                  return Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: LightModeColors.cardBorder),
                    ),
                    child: AppNetworkImage(
                      imageUrl: snap.data!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      memCacheWidth: 160,
                      borderRadius: BorderRadius.circular(11),
                    ),
                  );
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
                    item.marque!.trim().toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: LightModeColors.lightPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                ],
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: LightModeColors.dashboardTextPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Text(
                        'Qté: ${item.quantity}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Text(
                        '+${_formatPoints(item.pointsEarned)} pts',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                item.lineTotal.toStringAsFixed(3),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF065F46),
                ),
              ),
              const SizedBox(width: 2),
              const Text(
                'TND',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: LightModeColors.dashboardTextSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFFFFBEB);
    Color border = const Color(0xFFFDE68A);
    Color fg = const Color(0xFFB45309);
    String label = 'En attente';

    if (status == 'approved') {
      bg = const Color(0xFFECFDF5);
      border = const Color(0xFFA7F3D0);
      fg = const Color(0xFF047857);
      label = 'Validé';
    } else if (status == 'rejected') {
      bg = const Color(0xFFFEF2F2);
      border = const Color(0xFFFECACA);
      fg = const Color(0xFFB91C1C);
      label = 'Rejeté';
    } else if (status == 'cancelled') {
      bg = const Color(0xFFF1F5F9);
      border = const Color(0xFFE2E8F0);
      fg = const Color(0xFF475569);
      label = 'Annulé';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _defaultImageWidget() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: LightModeColors.lightBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LightModeColors.cardBorder),
      ),
      child: Icon(
        Icons.shopping_bag_outlined,
        color: LightModeColors.lightPrimary.withValues(alpha: 0.45),
        size: 22,
      ),
    );
  }
}
