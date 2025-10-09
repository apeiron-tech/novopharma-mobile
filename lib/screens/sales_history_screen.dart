import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/controllers/sales_history_provider.dart';
import 'package:novopharma/screens/product_screen.dart';
import 'package:novopharma/theme.dart';
import 'package:novopharma/widgets/bottom_navigation_bar.dart';
import 'package:novopharma/widgets/dashboard_header.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';

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
        Provider.of<SalesHistoryProvider>(context, listen: false)
            .fetchSalesHistory(authProvider.firebaseUser!.uid);
      }
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final provider = Provider.of<SalesHistoryProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.firebaseUser?.uid;

    if (userId == null) return; // Safety check

    final initialDate = (isStartDate ? provider.startDate : provider.endDate) ?? DateTime.now();
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
              child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
              onPressed: () {
                Provider.of<SalesHistoryProvider>(context, listen: false)
                    .deleteSale(sale);
                Navigator.of(ctx).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;
    
    return BottomNavigationScaffoldWrapper(
      currentIndex: 4, // History tab index
      onTap: (index) {},
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: DashboardHeader(
                  user: authProvider.userProfile,
                  onNotificationTap: () {},
                  titleWidget: Row(
                    children: [
                      const Icon(
                        Icons.receipt_long,
                        color: LightModeColors.dashboardTextPrimary,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.salesHistory,
                        style: const TextStyle(
                          color: LightModeColors.dashboardTextPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
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
                      return Center(child: Text(provider.error!, style: const TextStyle(color: Colors.red)));
                    }
                    if (provider.salesHistory.isEmpty) {
                      return Center(
                        child: Text(
                          l10n.noSalesRecorded,
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(8.0),
                      itemCount: provider.salesHistory.length,
                      itemBuilder: (context, index) {
                        final sale = provider.salesHistory[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: LightModeColors.novoPharmaBlue.withOpacity(0.1),
                              child: const Icon(Icons.shopping_bag_outlined, color: LightModeColors.novoPharmaBlue),
                            ),
                            title: Text(
                              sale.productNameSnapshot,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${l10n.quantity}: ${sale.quantity}  •  ${DateFormat.yMMMd().format(sale.saleDate)}',
                            ),
                            trailing: SizedBox(
                              width: 100,
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => ProductScreen(sale: sale),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _showDeleteConfirmationDialog(context, sale),
                                  ),
                                ],
                              ),
                            ),
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Consumer<SalesHistoryProvider>(
      builder: (context, provider, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            children: [
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
                  const SizedBox(width: 10),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    child: Text(l10n.clear, style: const TextStyle(color: Colors.red)),
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
                    icon: const Icon(Icons.search, size: 18),
                    label: Text(l10n.filter),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LightModeColors.novoPharmaBlue,
                      foregroundColor: Colors.white,
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
    return TextButton(
      onPressed: onPressed,
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.black)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              date != null ? DateFormat.yMMMd().format(date) : l10n.select,
              style: const TextStyle(color: LightModeColors.novoPharmaBlue, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}