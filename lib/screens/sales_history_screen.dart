import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/controllers/sales_history_provider.dart';
import 'package:novopharma/screens/product_screen.dart';
import 'package:novopharma/widgets/bottom_navigation_bar.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';
import 'package:novopharma/theme.dart';
import 'package:novopharma/services/product_service.dart';
import 'package:novopharma/services/gift_service.dart';
import 'package:novopharma/models/gift.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
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

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final provider = Provider.of<SalesHistoryProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.firebaseUser?.uid;

    if (userId == null) return; // Safety check

    final initialDate =
        (isStartDate ? provider.startDate : provider.endDate) ?? DateTime.now();
    final firstDate = DateTime(2020);
    final lastDate = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (pickedDate != null) {
      if (isStartDate) {
        provider.setStartDate(pickedDate);
      } else {
        provider.setEndDate(pickedDate);
      }
      // Fetch history immediately after setting the date
      provider.fetchSalesHistory(userId);
    }
  }

  void _showDeleteConfirmationDialog(BuildContext context, sale) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(l10n.confirmDeletion),
          content: Text(l10n.confirmDeletionMessage),
          actions: <Widget>[
            TextButton(
              child: Text(l10n.cancel),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            TextButton(
              child: Text(
                l10n.delete,
                style: const TextStyle(color: Colors.red),
              ),
              onPressed: () {
                Provider.of<SalesHistoryProvider>(
                  context,
                  listen: false,
                ).deleteSale(sale);
                Navigator.of(ctx).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: LightModeColors.lightPrimary,
              ),
              const SizedBox(width: 12),
              const Text(
                'Information',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: LightModeColors.dashboardTextPrimary,
                ),
              ),
            ],
          ),
          content: const Text(
            'Après validation, vos points sont automatiquement ajoutés à votre solde de points utilisables et peuvent être échangés en crédits Pluxee.',
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: LightModeColors.dashboardTextSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Fermer',
                style: TextStyle(
                  color: LightModeColors.lightPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  final Map<String, String?> _productImageCache = {};

  Future<String?> _getProductImage(String productId) async {
    if (_productImageCache.containsKey(productId)) {
      return _productImageCache[productId];
    }

    try {
      final productService = ProductService();
      final product = await productService.getProductById(productId);
      final imageUrl = product?.imageUrl ?? '';
      _productImageCache[productId] = imageUrl.isNotEmpty ? imageUrl : null;
      return _productImageCache[productId];
    } catch (e) {
      print('Error fetching product image for ID $productId: $e');
      _productImageCache[productId] = null;
      return null;
    }
  }

  final GiftService _giftService = GiftService();

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
              // Modern Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: LightModeColors.lightSurface,
                  boxShadow: [
                    BoxShadow(
                      color: LightModeColors.lightSurfaceVariant.withOpacity(
                        0.05,
                      ),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            LightModeColors.lightPrimary,
                            LightModeColors.lightTertiary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: LightModeColors.lightPrimary.withOpacity(
                              0.3,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: LightModeColors.lightOnPrimary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.salesHistory,
                            style: const TextStyle(
                              color: LightModeColors.dashboardTextPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.info_outline_rounded,
                        color: LightModeColors.lightPrimary,
                        size: 28,
                      ),
                      onPressed: () => _showInfoDialog(context),
                    ),
                  ],
                ),
              ),
              _buildFilterSection(l10n),
              Expanded(
                child: Consumer<SalesHistoryProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (provider.error != null) {
                      return Center(
                        child: Text(
                          provider.error!,
                          style: const TextStyle(
                            color: LightModeColors.lightError,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: provider.salesHistory.length,
                      itemBuilder: (context, index) {
                        final sale = provider.salesHistory[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: LightModeColors.lightSurface,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: LightModeColors.lightSurfaceVariant
                                    .withOpacity(0.06),
                                blurRadius: 15,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            leading: FutureBuilder<String?>(
                              future: _getProductImage(sale.productId),
                              builder: (context, snapshot) {
                                if (snapshot.hasData &&
                                    snapshot.data != null &&
                                    snapshot.data!.isNotEmpty) {
                                  return Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: LightModeColors.lightOutline,
                                        width: 1,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        snapshot.data!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color:
                                                LightModeColors.lightBackground,
                                            child: Icon(
                                              Icons
                                                  .image_not_supported_outlined,
                                              color: LightModeColors
                                                  .dashboardTextSecondary,
                                              size: 30,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                } else {
                                  return Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: LightModeColors.lightBackground,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: LightModeColors.lightOutline,
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.shopping_bag_rounded,
                                      color: LightModeColors.success,
                                      size: 30,
                                    ),
                                  );
                                }
                              },
                            ),
                            title: Text(
                              sale.productNameSnapshot,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: LightModeColors.dashboardTextPrimary,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: LightModeColors.success
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${l10n.quantity}: ${sale.quantity}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: LightModeColors.success,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  FutureBuilder<Map<String, dynamic>?>(
                                    future: _giftService
                                        .getGiftOperationBySaleId(sale.id),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData &&
                                          snapshot.data != null) {
                                        final giftId = snapshot.data!['giftId'];
                                        final giftQty =
                                            snapshot.data!['quantity'] ?? 0;
                                        final saleIdsRaw =
                                            snapshot.data!['saleIds'];
                                        final List<dynamic> saleIds =
                                            (saleIdsRaw is List &&
                                                saleIdsRaw.isNotEmpty)
                                            ? saleIdsRaw
                                            : (snapshot.data!['saleId'] != null
                                                  ? [snapshot.data!['saleId']]
                                                  : []);
                                        final bool isGrouped =
                                            saleIds.length > 1;

                                        final docId =
                                            snapshot.data!['id'] ?? '';

                                        return FutureBuilder<Gift?>(
                                          future: _giftService.getGiftById(
                                            giftId,
                                          ),
                                          builder: (context, giftSnapshot) {
                                            final giftTitle =
                                                giftSnapshot.data?.title ??
                                                '...';
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                top: 4,
                                                bottom: 4,
                                              ),
                                              child: Wrap(
                                                spacing: 12,
                                                runSpacing: 4,
                                                crossAxisAlignment:
                                                    WrapCrossAlignment.center,
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: LightModeColors
                                                          .novoPharmaBlue
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                      border: Border.all(
                                                        color: LightModeColors
                                                            .novoPharmaBlue
                                                            .withOpacity(0.2),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                          Icons
                                                              .card_giftcard_rounded,
                                                          size: 12,
                                                          color: LightModeColors
                                                              .novoPharmaBlue,
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Flexible(
                                                          child: Text(
                                                            '$giftTitle (x$giftQty)',
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: LightModeColors
                                                                  .novoPharmaBlue,
                                                            ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Wrap(
                                                    crossAxisAlignment:
                                                        WrapCrossAlignment
                                                            .center,
                                                    spacing: 2,
                                                    children: [
                                                      Text(
                                                        'ID Offre Cadeau: $docId',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: LightModeColors
                                                              .dashboardTextSecondary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                  Text(
                                    DateFormat.yMMMd().format(sale.saleDate),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: LightModeColors
                                          .dashboardTextSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: sale.status == 'pending'
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: LightModeColors.warning
                                              .withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.edit_rounded,
                                            color: LightModeColors.warning,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    ProductScreen(sale: sale),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: LightModeColors.lightError
                                              .withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.delete_rounded,
                                            color: LightModeColors.lightError,
                                            size: 20,
                                          ),
                                          onPressed: () =>
                                              _showDeleteConfirmationDialog(
                                                context,
                                                sale,
                                              ),
                                        ),
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                        );
                      },
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

  Widget _buildFilterSection(AppLocalizations l10n) {
    return Consumer<SalesHistoryProvider>(
      builder: (context, provider, child) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: LightModeColors.lightSurface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: LightModeColors.lightSurfaceVariant.withOpacity(0.06),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: LightModeColors.lightPrimary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.filter_list_rounded,
                      color: LightModeColors.lightPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.dateFilter,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: LightModeColors.dashboardTextPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildDateButton(
                      context: context,
                      label: l10n.start,
                      date: provider.startDate,
                      onPressed: () => _selectDate(context, true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDateButton(
                      context: context,
                      label: l10n.end,
                      date: provider.endDate,
                      onPressed: () => _selectDate(context, false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.clear, size: 18),
                    label: Text(l10n.clear),
                    style: TextButton.styleFrom(
                      foregroundColor: LightModeColors.lightError,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
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
                    icon: const Icon(Icons.search_rounded, size: 20),
                    label: Text(l10n.filter),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LightModeColors.lightPrimary,
                      foregroundColor: LightModeColors.lightOnPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
        );
      },
    );
  }

  Widget _buildDateButton({
    required BuildContext context,
    required String label,
    DateTime? date,
    required VoidCallback onPressed,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: LightModeColors.lightBackground,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: LightModeColors.lightOutline, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: LightModeColors.dashboardTextSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    color: LightModeColors.lightPrimary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      date != null
                          ? DateFormat.yMMMd().format(date)
                          : l10n.select,
                      style: TextStyle(
                        color: date != null
                            ? LightModeColors.dashboardTextPrimary
                            : LightModeColors.dashboardTextTertiary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
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
