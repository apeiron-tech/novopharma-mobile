import 'package:flutter/material.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/controllers/pluxee_redemption_provider.dart';
import 'package:novopharma/design/design.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/screens/pluxee_history_screen.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';

class PluxeeRedemptionScreen extends StatefulWidget {
  const PluxeeRedemptionScreen({super.key});

  @override
  State<PluxeeRedemptionScreen> createState() => _PluxeeRedemptionScreenState();
}

class _PluxeeRedemptionScreenState extends State<PluxeeRedemptionScreen> {
  final TextEditingController _pointsController = TextEditingController();
  double _selectedPoints = 0.0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _pointsController.dispose();
    super.dispose();
  }

  void _showRedemptionDialog(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final pluxeeProvider = Provider.of<PluxeeRedemptionProvider>(
      context,
      listen: false,
    );
    final currentUser = authProvider.userProfile;
    final l10n = AppLocalizations.of(context)!;

    if (currentUser == null) return;

    _pointsController.clear();
    _selectedPoints = 0.0;

    // The sheet's own MediaQuery has the status bar inset removed, so read it
    // from the page to keep the sheet clear of it when the keyboard is up.
    final topInset = MediaQuery.paddingOf(context).top;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        // Room left for the form once the keyboard, the status bar and the
        // sheet's own chrome (handle, padding, home indicator) are taken out.
        final roomForBody =
            media.size.height - media.viewInsets.bottom - topInset - 96;
        final maxBodyHeight = roomForBody < 160 ? 160.0 : roomForBody;

        return Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: GlassSheet(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxBodyHeight),
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  final availablePoints =
                      currentUser.points - pluxeeProvider.totalPendingPoints;
                  final pluxeeCredits = pluxeeProvider.calculatePluxeeCredits(
                    _selectedPoints,
                  );
                  final belowMinimum =
                      _selectedPoints > 0 && _selectedPoints < 50;
                  final canSubmit =
                      _selectedPoints >= 50 &&
                      _selectedPoints <= availablePoints &&
                      !_isSubmitting;

                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.redeemPluxeeCredits,
                          style: AppText.display(size: 22),
                        ),
                        const SizedBox(height: 16),

                        // What can be spent.
                        _SheetPanel(
                          child: Row(
                            children: [
                              const TintIcon(
                                icon: Icons.account_balance_wallet_rounded,
                                tone: Tone.amber,
                                size: 40,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  l10n.usablePoints,
                                  style: AppText.label(
                                    size: 13.5,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formatPoints(availablePoints),
                                style: AppText.display(size: 24),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // The amount.
                        TextField(
                          controller: _pointsController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: AppText.display(size: 22),
                          cursorColor: AppColors.coral,
                          decoration: InputDecoration(
                            labelText: l10n.pointsToRedeem,
                            hintText: l10n.enterAmount,
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.72),
                            prefixIcon: const Icon(
                              Icons.stars_rounded,
                              color: AppColors.amber,
                            ),
                            suffixText: 'pts',
                            suffixStyle: AppText.label(size: 14),
                          ),
                          onChanged: (value) {
                            setModalState(() {
                              _selectedPoints = double.tryParse(value) ?? 0.0;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            l10n.minimumRedemptionAmount(50),
                            style: AppText.label(
                              size: 12.5,
                              letterSpacing: 0,
                              color: belowMinimum
                                  ? AppColors.coralDeep
                                  : AppColors.textMuted,
                              weight: belowMinimum
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // What it becomes, live as the amount changes.
                        _SheetPanel(
                          tint: AppColors.mintTint,
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.youWillReceive,
                                style: AppText.label(
                                  size: 13,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 6),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: _RollingAmount(
                                  value: pluxeeCredits,
                                  style: AppText.display(size: 28),
                                  format: (v) => l10n.pluxeeCreditsAmount(
                                    v.toStringAsFixed(2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.swap_horiz_rounded,
                                    size: 18,
                                    color: AppColors.mintDeep,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      l10n.conversionRate(
                                        pluxeeProvider.conversionRate.toInt(),
                                      ),
                                      style: AppText.label(
                                        size: 12.5,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: SecondaryButton(
                                label: l10n.cancel,
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: PrimaryButton.coral(
                                label: l10n.submitRequest,
                                height: 52,
                                loading: _isSubmitting,
                                onPressed: canSubmit
                                    ? () async {
                                        setState(() => _isSubmitting = true);

                                        final error = await pluxeeProvider
                                            .createRedemptionRequest(
                                              _selectedPoints,
                                            );

                                        setState(() => _isSubmitting = false);

                                        if (mounted) {
                                          Navigator.pop(ctx);

                                          if (error == null) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  l10n.requestSubmittedSuccess,
                                                ),
                                                backgroundColor:
                                                    AppColors.mintDeep,
                                                duration: const Duration(
                                                  seconds: 3,
                                                ),
                                              ),
                                            );
                                            celebrate(this.context);
                                          } else {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(error),
                                                backgroundColor:
                                                    AppColors.coralDeep,
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final media = MediaQuery.of(context);
    final maxWidth = media.size.width > 600 ? 640.0 : double.infinity;

    Widget centered(Widget child) => Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        );

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: AppBackground(
        accent: Tone.amber,
        child: Consumer2<AuthProvider, PluxeeRedemptionProvider>(
          builder: (context, authProvider, pluxeeProvider, child) {
            final currentUser = authProvider.userProfile;

            if (currentUser == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkHero(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.page,
                      10,
                      AppSpace.page,
                      22,
                    ),
                    child: _buildTopBar(context, l10n),
                  ),
                  Expanded(
                    child: EmptyState(
                      icon: Icons.lock_outline_rounded,
                      title: l10n.signIn,
                      tone: Tone.amber,
                    ),
                  ),
                ],
              );
            }

            final availablePoints =
                currentUser.points - pluxeeProvider.totalPendingPoints;
            final pendingPoints = pluxeeProvider.totalPendingPoints;

            return SingleChildScrollView(
              padding: EdgeInsets.only(bottom: media.padding.bottom + 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Ink hero: what you have, what it is worth, spend it.
                  InkHero(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.page,
                      10,
                      AppSpace.page,
                      26,
                    ),
                    child: centered(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Entrance(
                            offset: const Offset(0, -12),
                            child: _buildTopBar(context, l10n),
                          ),
                          const SizedBox(height: 26),
                          Entrance(
                            delay: const Duration(milliseconds: 100),
                            scaleFrom: 0.96,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.points,
                                  style: AppText.label(
                                    size: 14,
                                    letterSpacing: 0,
                                    color: Colors.white.withValues(alpha: 0.78),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: CountUp(
                                    value: availablePoints,
                                    style: AppText.display(
                                      size: 68,
                                      weight: FontWeight.w800,
                                      color: Colors.white,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Entrance(
                            delay: const Duration(milliseconds: 180),
                            child: _buildRateCard(
                              l10n,
                              pluxeeProvider,
                              pendingPoints,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Entrance(
                            delay: const Duration(milliseconds: 240),
                            child: PrimaryButton.coral(
                              label: l10n.redeemPointsNow,
                              icon: Icons.card_giftcard_rounded,
                              onPressed: availablePoints > 0
                                  ? () => _showRedemptionDialog(context)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // On the canvas: how it works, and where past requests live.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.page,
                      24,
                      AppSpace.page,
                      0,
                    ),
                    child: centered(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Entrance(
                            delay: const Duration(milliseconds: 300),
                            child: Text(
                              l10n.redeemPluxeeCredits,
                              style: AppText.display(size: 22),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Entrance(
                            delay: const Duration(milliseconds: 360),
                            child: SoftCard(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                20,
                                20,
                                8,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const BlisterIcon(
                                        icon: Icons.card_giftcard_rounded,
                                        tone: Tone.amber,
                                        size: 48,
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          l10n.howItWorks,
                                          style: AppText.display(
                                            size: 18,
                                            height: 1.18,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  _buildInfoStep(
                                    '1',
                                    l10n.choosePointsToConvert,
                                  ),
                                  _buildInfoStep('2', l10n.submitForReview),
                                  _buildInfoStep(
                                    '3',
                                    Localizations.localeOf(
                                              context,
                                            ).languageCode ==
                                            'fr'
                                        ? 'Votre demande sera prise en charge et une réponse vous sera communiquée sous 72 heures ouvrées.'
                                        : 'Your request will be processed and a response will be provided within 72 business hours.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Entrance(
                            delay: const Duration(milliseconds: 420),
                            child: SoftCard(
                              radius: AppRadii.md,
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                14,
                                12,
                                14,
                              ),
                              semanticLabel: l10n.viewRedemptionHistory,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const PluxeeHistoryScreen(),
                                  ),
                                );
                              },
                              child: Row(
                                children: [
                                  const TintIcon(
                                    icon: Icons.history_rounded,
                                    tone: Tone.amber,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      l10n.viewRedemptionHistory,
                                      style: AppText.body(
                                        size: 15.5,
                                        weight: FontWeight.w700,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.textMuted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
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

  /// Back button and the screen's name, on ink.
  Widget _buildTopBar(BuildContext context, AppLocalizations l10n) {
    return Row(
      children: [
        GlassIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onTap: () => Navigator.pop(context),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            l10n.pluxeeCredits,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.display(
              size: 20,
              color: Colors.white,
              height: 1.12,
            ),
          ),
        ),
      ],
    );
  }

  /// The exchange rate and, when there are any, the points already tied up
  /// in requests awaiting approval.
  Widget _buildRateCard(
    AppLocalizations l10n,
    PluxeeRedemptionProvider pluxeeProvider,
    double pendingPoints,
  ) {
    return SoftCard(
      style: GlassStyle.dark,
      blur: Glass.frost,
      radius: AppRadii.md,
      shadow: false,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.swap_horiz_rounded,
                  color: AppColors.mintBright,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.conversionRate(pluxeeProvider.conversionRate.toInt()),
                    style: AppText.body(
                      size: 14.5,
                      weight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (pendingPoints > 0) ...[
            Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.16),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    color: AppColors.amber,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.pointsPendingApproval(pendingPoints),
                      style: AppText.body(
                        size: 14,
                        weight: FontWeight.w600,
                        color: AppColors.amber,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.amberTint,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: AppText.display(
                  size: 15,
                  color: AppColors.amberDeep,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                text,
                style: AppText.body(size: 14.5, height: 1.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tinted inset inside the redemption sheet. No blur of its own: the sheet
/// behind it is already frosted.
class _SheetPanel extends StatelessWidget {
  final Widget child;
  final Color tint;
  final EdgeInsetsGeometry padding;

  const _SheetPanel({
    required this.child,
    this.tint = Colors.white,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
      ),
      child: child,
    );
  }
}

/// Rolls a decimal amount to its new value without rounding it on the way,
/// so a credit figure stays exact while it moves.
class _RollingAmount extends StatelessWidget {
  final double value;
  final TextStyle style;
  final String Function(double) format;

  const _RollingAmount({
    required this.value,
    required this.style,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: AppMotion.reduced(context) ? Duration.zero : AppMotion.medium,
      curve: AppMotion.emphasized,
      builder: (context, v, _) =>
          Text(format(v), style: style, maxLines: 1, softWrap: false),
    );
  }
}
