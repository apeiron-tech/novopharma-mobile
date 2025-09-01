import 'package:flutter/material.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/controllers/scan_provider.dart';
import 'package:novopharma/models/campaign.dart';
import 'package:novopharma/models/goal.dart';
import 'package:novopharma/models/product.dart';
import 'package:novopharma/theme.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';

class ProductScreen extends StatefulWidget {
  final String sku;

  const ProductScreen({super.key, required this.sku});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ScanProvider>(
        context,
        listen: false,
      ).fetchProductAndRelatedData(widget.sku);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(l10n.scannedProduct),
        backgroundColor: Colors.white,
        foregroundColor: LightModeColors.dashboardTextPrimary,
        elevation: 1,
      ),
      body: Consumer<ScanProvider>(
        builder: (context, scanProvider, child) {
          if (scanProvider.isLoading && scanProvider.scannedProduct == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (scanProvider.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  scanProvider.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, color: Colors.red),
                ),
              ),
            );
          }

          if (scanProvider.scannedProduct == null) {
            return Center(
              child: Text(
                l10n.productDetailsAppearHere,
                style: const TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProductHeader(scanProvider.scannedProduct!),
                      const SizedBox(height: 24),
                      _buildDetailsCard(scanProvider, l10n),
                      const SizedBox(height: 24),
                      if (scanProvider.matchingCampaigns.isNotEmpty)
                        _buildCampaignsSection(scanProvider.matchingCampaigns, l10n),
                      if (scanProvider.matchingGoals.isNotEmpty)
                        _buildGoalsSection(scanProvider.matchingGoals, l10n),
                      if (scanProvider.recommendedProducts.isNotEmpty)
                        _buildRecommendedSection(
                          scanProvider.recommendedProducts,
                          l10n,
                        ),
                    ],
                  ),
                ),
              ),
              _buildBottomBar(context, l10n),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProductHeader(Product product) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product.marque,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          product.name,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: LightModeColors.dashboardTextPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsCard(ScanProvider scanProvider, AppLocalizations l10n) {
    final product = scanProvider.scannedProduct!;
    final quantity = scanProvider.quantity;
    final totalPrice = (product.price * quantity).toStringAsFixed(2);
    final totalPoints = product.points * quantity;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.saleDetails,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.availableStock,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              Text(
                '${product.stock}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.quantity, style: const TextStyle(fontSize: 16)),
              _buildQuantitySelector(scanProvider),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.sell_outlined, color: Colors.grey.shade600, size: 20),
              const SizedBox(width: 8),
              Text(l10n.totalPrice, style: const TextStyle(fontSize: 16)),
              const Spacer(),
              Text(
                '\$$totalPrice',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.star_outline, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text(l10n.totalPoints, style: const TextStyle(fontSize: 16)),
              const Spacer(),
              Text(
                '$totalPoints pts',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: LightModeColors.novoPharmaBlue,
                ),
              ),
            ],
          ),
          if (product.protocol != null && product.protocol!.isNotEmpty) ...[
            const Divider(height: 24),
            Text(
              l10n.protocol,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              product.protocol!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuantitySelector(ScanProvider scanProvider) {
    final bool canIncrement =
        scanProvider.quantity < (scanProvider.scannedProduct?.stock ?? 0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            onPressed: scanProvider.decrementQuantity,
            splashRadius: 20,
          ),
          Text(
            '${scanProvider.quantity}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: Icon(
              Icons.add,
              size: 18,
              color: canIncrement ? Colors.black : Colors.grey,
            ),
            onPressed: canIncrement ? scanProvider.incrementQuantity : null,
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildCampaignsSection(List<Campaign> campaigns, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(l10n.activeCampaigns),
        ...campaigns.map(
          (campaign) => Card(
            elevation: 0,
            color: Colors.amber.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.amber.shade200),
            ),
            child: ListTile(
              leading: Icon(Icons.campaign, color: Colors.amber.shade700),
              title: Text(
                campaign.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(campaign.description),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildGoalsSection(List<Goal> goals, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(l10n.relatedGoals),
        ...goals.map(
          (goal) => Card(
            elevation: 0,
            color: Colors.green.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.green.shade200),
            ),
            child: ListTile(
              leading: Icon(Icons.flag, color: Colors.green.shade700),
              title: Text(
                goal.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text('Reward: ${goal.rewardPoints} points'),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildRecommendedSection(List<Product> products, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(l10n.recommendedWith),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: products
              .map(
                (product) => Chip(
                  label: Text(product.name),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, AppLocalizations l10n) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final scanProvider = Provider.of<ScanProvider>(context, listen: false);
    final isAvailable = scanProvider.isStockAvailable;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            icon: Icon(
              isAvailable ? Icons.check : Icons.block,
              color: Colors.white,
            ),
            label: Text(
              isAvailable ? l10n.confirmSale : l10n.outOfStock,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isAvailable
                  ? LightModeColors.novoPharmaBlue
                  : Colors.grey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: isAvailable
                ? () async {
                    final user = authProvider.userProfile;
                    if (user == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'You must be logged in to record a sale.',
                          ),
                        ),
                      );
                      return;
                    }
                    if (user.pharmacyId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'User pharmacy information is missing.',
                          ),
                        ),
                      );
                      return;
                    }

                    final success = await scanProvider.confirmSale(
                      userId: user.uid,
                      pharmacyId: user.pharmacyId,
                    );

                    if (mounted && success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sale confirmed successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      Navigator.of(context).pop();
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            scanProvider.errorMessage ??
                                'An unknown error occurred.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                : null,
          ),
        ),
      ),
    );
  }
}