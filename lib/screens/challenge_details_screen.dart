import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/models/challenge.dart';
import 'package:novopharma/models/product.dart';
import 'package:novopharma/models/user_model.dart';
import 'package:novopharma/services/challenge_service.dart';
import 'package:novopharma/services/pharmacy_service.dart';
import 'package:novopharma/services/product_service.dart';
import 'package:novopharma/services/user_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novopharma/design/design.dart';
import 'product_screen.dart';

class _ChallengeDetailsData {
  final Challenge? challenge;
  final List<Product> products;
  final String? userCategory;
  final String? userRole;

  _ChallengeDetailsData({this.challenge, this.products = const [], this.userCategory, this.userRole});
}

class ChallengeDetailsScreen extends StatefulWidget {
  final String challengeId;
  const ChallengeDetailsScreen({super.key, required this.challengeId});

  @override
  State<ChallengeDetailsScreen> createState() => _ChallengeDetailsScreenState();
}

class _ChallengeDetailsScreenState extends State<ChallengeDetailsScreen> {
  final ChallengeService _challengeService = ChallengeService();
  final ProductService _productService = ProductService();
  final UserService _userService = UserService();
  final PharmacyService _pharmacyService = PharmacyService();

  late Future<_ChallengeDetailsData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_ChallengeDetailsData> _loadData() async {
    final challenge = await _challengeService.getChallengeById(widget.challengeId);
    if (challenge == null) return _ChallengeDetailsData(challenge: null);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.firebaseUser?.uid;

    final [products, user] = await Future.wait([
      challenge.productIds.isNotEmpty
          ? _productService.getProductsByIds(challenge.productIds)
          : Future.value(<Product>[]),
      userId != null ? _userService.getUser(userId) : Future.value(null),
    ]);

    String? category;
    final userModel = user as UserModel?;
    if (userModel != null) {
      String? resolvedPharmacyId;
      if (userModel.role == 'Dermo-conseiller') {
        final prefs = await SharedPreferences.getInstance();
        resolvedPharmacyId = prefs.getString('active_pharmacy_id');
      } else {
        resolvedPharmacyId = userModel.pharmacyId;
      }

      if (resolvedPharmacyId != null && resolvedPharmacyId.isNotEmpty) {
        final pharmacy = await _pharmacyService.getPharmacy(resolvedPharmacyId);
        final cat = pharmacy?.clientCategory;
        category = (cat == null || cat.isEmpty) ? 'Pharmacie' : cat;
      } else {
        category = 'Pharmacie';
      }
    } else {
      category = 'Pharmacie';
    }

    return _ChallengeDetailsData(
      challenge: challenge,
      products: products as List<Product>,
      userCategory: category,
      userRole: userModel?.role,
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: AppBackground(
        accent: Tone.indigo,
        child: FutureBuilder<_ChallengeDetailsData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkHero(
                    padding: _heroPadding,
                    child: _buildTopBar(context),
                  ),
                  const Expanded(
                    child: SkeletonList(
                      count: 4,
                      itemHeight: 96,
                      padding: EdgeInsets.fromLTRB(
                        AppSpace.page,
                        22,
                        AppSpace.page,
                        0,
                      ),
                    ),
                  ),
                ],
              );
            }

            if (snapshot.hasError || !snapshot.hasData || snapshot.data?.challenge == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkHero(
                    padding: _heroPadding,
                    child: _buildTopBar(context),
                  ),
                  const Expanded(
                    child: EmptyState(
                      icon: Icons.error_outline_rounded,
                      title: "Erreur lors du chargement des données.",
                      tone: Tone.coral,
                    ),
                  ),
                ],
              );
            }

            final data = snapshot.data!;
            final challenge = data.challenge!;

            return SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom + 28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildChallengeHero(challenge),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.page,
                      24,
                      AppSpace.page,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (challenge.description.isNotEmpty) ...[
                          _buildSectionTitle("Description"),
                          const SizedBox(height: 12),
                          Entrance(
                            delay: const Duration(milliseconds: 240),
                            child: SoftCard(
                              padding: const EdgeInsets.all(18),
                              child: Text(
                                challenge.description,
                                style: AppText.body(size: 15.5, height: 1.55),
                              ),
                            ),
                          ),
                          const SizedBox(height: 26),
                        ],
                        _buildSectionTitle("Produits du challenge"),
                        const SizedBox(height: 14),
                        for (var i = 0; i < data.products.length; i++)
                          Entrance.staggered(
                            index: i,
                            base: const Duration(milliseconds: 300),
                            child: _buildProductCard(context, data.products[i], data.userCategory, challenge, userRole: data.userRole),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static const _heroPadding = EdgeInsets.fromLTRB(
    AppSpace.page,
    10,
    AppSpace.page,
    26,
  );

  Widget _buildTopBar(BuildContext context, {Widget? trailing}) {
    return Row(
      children: [
        GlassIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onTap: () => Navigator.maybePop(context),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            "Challenge",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.display(size: 20, color: Colors.white),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing],
      ],
    );
  }

  Widget _buildChallengeHero(Challenge challenge) {
    return InkHero(
      padding: _heroPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Entrance(
            offset: const Offset(0, -12),
            child: _buildTopBar(
              context,
              // Status
              trailing: const TonePill(
                label: "Challenge actif",
                tone: Tone.mint,
                icon: Icons.bolt_rounded,
              ),
            ),
          ),
          if (challenge.imageUrl.isNotEmpty) ...[
            const SizedBox(height: 20),
            Entrance(
              delay: const Duration(milliseconds: 80),
              scaleFrom: 0.96,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: CachedNetworkImage(
                        imageUrl: challenge.imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => ColoredBox(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        errorWidget: (context, url, error) => ColoredBox(
                          color: Colors.white.withValues(alpha: 0.1),
                          child: const Icon(
                            Icons.emoji_events_rounded,
                            size: 44,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // The lit rim that seats the picture in the glass.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.24),
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Entrance(
            delay: const Duration(milliseconds: 140),
            child: Text(
              challenge.title,
              style: AppText.display(
                size: 26,
                color: Colors.white,
                height: 1.12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Entrance(
            delay: const Duration(milliseconds: 200),
            child: Row(
              children: [
                _buildInfoCard(
                  Icons.calendar_today_rounded,
                  "Début",
                  _formatDate(challenge.startDate),
                ),
                const SizedBox(width: 12),
                _buildInfoCard(
                  Icons.event_available_rounded,
                  "Fin",
                  _formatDate(challenge.endDate),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Expanded(
      child: SoftCard(
        style: GlassStyle.dark,
        blur: Glass.frost,
        radius: AppRadii.md,
        shadow: false,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppText.label(
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.78),
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      maxLines: 1,
                      style: AppText.display(size: 15, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return SectionHeader(title: title);
  }

  Widget _buildProductCard(BuildContext context, Product product, String? category, Challenge challenge, {String? userRole}) {
    final now = DateTime.now();
    double points = product.getPoints(category, userRole: userRole);
    
    // Check if we should use challenge points
    final effectiveCategory = userRole == 'Dermo-conseiller'
        ? 'Dermo-conseiller'
        : ((category == null || category.isEmpty) ? 'Pharmacie' : category);

    if (challenge.status == 'active' && 
        challenge.hasSalePoints && 
        !now.isBefore(challenge.startDate) && 
        !now.isAfter(challenge.endDate) &&
        (challenge.clientCategory.contains(effectiveCategory) ||
         (userRole == 'Dermo-conseiller' && challenge.clientCategory.contains(category ?? 'Pharmacie')) ||
         (category == 'Pharmacie' && challenge.clientCategory.contains('')))) {
      points = challenge.salePoints;
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        radius: AppRadii.md,
        padding: const EdgeInsets.all(12),
        semanticLabel: product.name,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductScreen(id: product.id),
            ),
          );
        },
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              child: Container(
                width: 70,
                height: 70,
                color: AppColors.surface,
                child: CachedNetworkImage(
                  imageUrl: product.imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Icon(Icons.image_rounded, color: AppColors.textFaint),
                  errorWidget: (context, url, error) => const Icon(Icons.broken_image_rounded, color: AppColors.textFaint),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: AppText.display(size: 16, height: 1.15),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${product.marque} • ${product.category}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(
                      size: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TonePill(
                    label: "${points % 1 == 0 ? points.toInt() : points} pts",
                    tone: Tone.amber,
                    icon: Icons.star_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textFaint,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }
}
