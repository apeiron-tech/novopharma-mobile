import 'package:flutter/material.dart';
import 'package:novopharma/design/design.dart';
import 'package:novopharma/models/goal.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';
import 'package:novopharma/services/product_service.dart';
import 'package:novopharma/services/pharmacy_service.dart';
import 'package:novopharma/widgets/progress_ring.dart';

class GoalDetailsScreen extends StatefulWidget {
  final Goal goal;

  const GoalDetailsScreen({super.key, required this.goal});

  @override
  State<GoalDetailsScreen> createState() => _GoalDetailsScreenState();
}

class _GoalDetailsScreenState extends State<GoalDetailsScreen> {
  final ProductService _productService = ProductService();
  final PharmacyService _pharmacyService = PharmacyService();

  Future<List<String>>? _productNamesFuture;
  Future<List<String>>? _pharmacyNamesFuture;

  @override
  void initState() {
    super.initState();
    _fetchCriteriaNames();
  }

  void _fetchCriteriaNames() {
    final criteria = widget.goal.criteria;
    if (criteria.products.isNotEmpty) {
      _productNamesFuture = _productService
          .getProductsByIds(criteria.products)
          .then((products) => products.map((p) => p.name).toList());
    }
    if (criteria.pharmacyIds.isNotEmpty) {
      _pharmacyNamesFuture = _pharmacyService
          .getPharmaciesByIds(criteria.pharmacyIds)
          .then((pharmacies) => pharmacies.map((p) => p.name).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: AppBackground(
        accent: Tone.coral,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom + 28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ink hero: which objective, and how far along.
              InkHero(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.page,
                  10,
                  AppSpace.page,
                  26,
                ),
                child: _buildHero(context, l10n),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.page,
                  22,
                  AppSpace.page,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.goal.description.isNotEmpty) ...[
                      Entrance(
                        delay: const Duration(milliseconds: 240),
                        child: SoftCard(
                          padding: const EdgeInsets.all(18),
                          child: Text(
                            widget.goal.description,
                            style: AppText.body(size: 15.5, height: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                    ],
                    SectionHeader(title: l10n.eligibilityCriteria),
                    const SizedBox(height: 14),
                    _buildCriteriaSection(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context, AppLocalizations l10n) {
    final goal = widget.goal;
    final int currentProgress = goal.userProgress?.progressValue ?? 0;
    final bool isCompleted = goal.userProgress?.status == 'completed';
    final double progressPercent = goal.targetValue > 0
        ? (currentProgress / goal.targetValue).clamp(0.0, 1.0)
        : 0.0;
    final String target = goal.metric == 'revenue'
        ? '/ ${formatPoints(goal.targetValue.toInt())} TND'
        : '/ ${formatPoints(goal.targetValue.toInt())}';
    final muted = Colors.white.withValues(alpha: 0.78);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Entrance(
          offset: const Offset(0, -12),
          child: Row(
            children: [
              GlassIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onTap: () => Navigator.maybePop(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.goalDetails,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.display(size: 20, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Entrance(
          delay: const Duration(milliseconds: 80),
          child: Text(
            goal.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppText.display(size: 26, color: Colors.white, height: 1.12),
          ),
        ),
        const SizedBox(height: 18),
        Entrance(
          delay: const Duration(milliseconds: 160),
          scaleFrom: 0.96,
          child: SoftCard(
            style: GlassStyle.dark,
            blur: Glass.frost,
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                ProgressRing(
                  progress: progressPercent,
                  size: 104,
                  strokeWidth: 11,
                  trackColor: Colors.white.withValues(alpha: 0.16),
                  progressColor: isCompleted
                      ? AppColors.mintBright
                      : AppColors.coral,
                  textStyle: AppText.display(size: 28, color: Colors.white),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.progress,
                        style: AppText.label(
                          size: 12.5,
                          color: muted,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            CountUp(
                              value: currentProgress,
                              style: AppText.display(
                                size: 34,
                                color: Colors.white,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              target,
                              style: AppText.label(size: 14, color: muted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TonePill(
                            label: goal.rewardText,
                            tone: Tone.amber,
                            icon: Icons.star_rounded,
                          ),
                          _buildHeroChip(
                            Icons.schedule_rounded,
                            goal.getTimeRemaining(l10n),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label(
                size: 12,
                weight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriteriaSection(BuildContext context) {
    final criteria = widget.goal.criteria;
    final l10n = AppLocalizations.of(context)!;
    final List<Widget> criteriaWidgets = [];

    if (criteria.products.isNotEmpty) {
      criteriaWidgets.add(
        _buildFutureCriteriaCard(
          icon: Icons.inventory_2_rounded,
          title: l10n.eligibleProducts,
          future: _productNamesFuture,
        ),
      );
    }
    if (criteria.pharmacyIds.isNotEmpty) {
      criteriaWidgets.add(
        _buildFutureCriteriaCard(
          icon: Icons.local_pharmacy_rounded,
          title: l10n.eligiblePharmacies,
          future: _pharmacyNamesFuture,
        ),
      );
    }
    if (criteria.brands.isNotEmpty) {
      criteriaWidgets.add(
        _buildCriteriaCard(
          icon: Icons.stars_rounded,
          title: l10n.eligibleBrands,
          items: criteria.brands,
        ),
      );
    }
    if (criteria.categories.isNotEmpty) {
      criteriaWidgets.add(
        _buildCriteriaCard(
          icon: Icons.category_rounded,
          title: l10n.eligibleCategories,
          items: criteria.categories,
        ),
      );
    }
    if (criteria.zones.isNotEmpty) {
      criteriaWidgets.add(
        _buildCriteriaCard(
          icon: Icons.public_rounded,
          title: l10n.eligibleZones,
          items: criteria.zones,
        ),
      );
    }

    if (criteriaWidgets.isEmpty) {
      return SoftCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const TintIcon(
              icon: Icons.all_inclusive_rounded,
              tone: Tone.mint,
              size: 40,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                l10n.noSpecificCriteria,
                style: AppText.body(size: 15, weight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: criteriaWidgets,
    );
  }

  Widget _buildFutureCriteriaCard({
    required IconData icon,
    required String title,
    required Future<List<String>>? future,
  }) {
    return FutureBuilder<List<String>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildCriteriaCard(
            icon: icon,
            title: title,
            items: [],
            isLoading: true,
          );
        } else if (snapshot.hasError) {
          return _buildCriteriaCard(
            icon: icon,
            title: title,
            items: ['Error loading data'],
          );
        } else if (snapshot.hasData) {
          return _buildCriteriaCard(
            icon: icon,
            title: title,
            items: snapshot.data!,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildCriteriaCard({
    required IconData icon,
    required String title,
    required List<String> items,
    bool isLoading = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SoftCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TintIcon(icon: icon, tone: Tone.coral, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.display(size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (isLoading)
              const Center(child: CapsuleLoader(size: 32))
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 160),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: items
                        .map(
                          (item) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.coralTint,
                              borderRadius: BorderRadius.circular(
                                AppRadii.pill,
                              ),
                            ),
                            child: Text(
                              item,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.label(
                                size: 13,
                                color: AppColors.text,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
