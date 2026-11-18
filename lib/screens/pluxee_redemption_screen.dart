import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/controllers/pluxee_redemption_provider.dart';
import 'package:novopharma/theme.dart';
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) {
            final availablePoints = currentUser.points - pluxeeProvider.totalPendingPoints;
            final pluxeeCredits = pluxeeProvider.calculatePluxeeCredits(
              _selectedPoints,
            );

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.redeemPluxeeCredits,
                    style: GoogleFonts.montserrat(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: LightModeColors.dashboardTextPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: LightModeColors.novoPharmaLightBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          l10n.usablePoints,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$availablePoints',
                          style: GoogleFonts.inter(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: LightModeColors.novoPharmaBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _pointsController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.pointsToRedeem,
                      hintText: l10n.enterAmount,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.stars),
                      suffixText: 'pts',
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        _selectedPoints = double.tryParse(value) ?? 0.0;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.minimumRedemptionAmount(50),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _selectedPoints > 0 && _selectedPoints < 50
                          ? LightModeColors.lightError
                          : LightModeColors.dashboardTextSecondary,
                      fontWeight: _selectedPoints > 0 && _selectedPoints < 50
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.youWillReceive,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          l10n.pluxeeCreditsAmount(
                            pluxeeCredits.toStringAsFixed(2),
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: LightModeColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.conversionRate(pluxeeProvider.conversionRate.toInt()),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: LightModeColors.dashboardTextSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: LightModeColors.novoPharmaBlue
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                side: BorderSide.none,
                                foregroundColor: LightModeColors.novoPharmaBlue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                overlayColor: LightModeColors.novoPharmaBlue
                                    .withValues(alpha: 0.1),
                              ),
                              child: Text(
                                l10n.cancel,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: LightModeColors.novoPharmaBlue,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow:
                                  _selectedPoints >= 50 &&
                                      _selectedPoints <= availablePoints &&
                                      !_isSubmitting
                                  ? [
                                      BoxShadow(
                                        color: LightModeColors.novoPharmaBlue
                                            .withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: ElevatedButton(
                              onPressed:
                                  (_selectedPoints >= 50 &&
                                      _selectedPoints <= availablePoints &&
                                      !_isSubmitting)
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
                                                  LightModeColors.success,
                                              duration: const Duration(
                                                seconds: 3,
                                              ),
                                            ),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(error),
                                              backgroundColor:
                                                  LightModeColors.lightError,
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    _selectedPoints >= 50 &&
                                        _selectedPoints <= availablePoints &&
                                        !_isSubmitting
                                    ? LightModeColors.novoPharmaBlue
                                    : Colors.grey.shade400,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                shadowColor:
                                    _selectedPoints >= 50 &&
                                        _selectedPoints <= availablePoints &&
                                        !_isSubmitting
                                    ? LightModeColors.novoPharmaBlue
                                          .withValues(alpha: 0.3)
                                    : Colors.transparent,
                                elevation:
                                    _selectedPoints >= 50 &&
                                        _selectedPoints <= availablePoints &&
                                        !_isSubmitting
                                    ? 4.0
                                    : 0.0,
                                overlayColor:
                                    _selectedPoints >= 50 &&
                                        _selectedPoints <= availablePoints &&
                                        !_isSubmitting
                                    ? LightModeColors.novoPharmaBlue
                                          .withValues(alpha: 0.2)
                                    : Colors.grey.shade400.withValues(alpha: 0.2),
                              ),
                              child: _isSubmitting
                                  ? const Center(
                                      child: SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      ),
                                    )
                                  : Text(
                                      l10n.submitRequest,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: LightModeColors.lightBackground,
      appBar: AppBar(
        backgroundColor: LightModeColors.lightSurface,
        elevation: 0,
        surfaceTintColor: LightModeColors.lightSurface,
        scrolledUnderElevation: 6.0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: LightModeColors.lightSurfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: LightModeColors.dashboardTextPrimary,
              size: 18,
            ),
          ),
          onPressed: () => Navigator.pop(context),
          iconSize: 20,
          splashRadius: 20,
        ),
        title: Text(
          l10n.pluxeeCredits,
          style: GoogleFonts.montserrat(
            color: LightModeColors.dashboardTextPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Consumer2<AuthProvider, PluxeeRedemptionProvider>(
        builder: (context, authProvider, pluxeeProvider, child) {
          final currentUser = authProvider.userProfile;

          if (currentUser == null) {
            return Center(child: Text(l10n.signIn));
          }

          final availablePoints = currentUser.points - pluxeeProvider.totalPendingPoints;
          final pendingPoints = pluxeeProvider.totalPendingPoints;

          return SingleChildScrollView(
            child: Column(
              children: [
                // Header Section with Dark Gradient
                Container(
                  width: double.infinity,

                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 40,
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: LightModeColors.lightOnPrimary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: LightModeColors.lightOnPrimary.withValues(
                              alpha: 0.2,
                            ),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          l10n.points.toUpperCase(),
                          style: GoogleFonts.inter(
                            color: LightModeColors.lightOnPrimaryContainer,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '$availablePoints',
                        style: GoogleFonts.inter(
                          color: LightModeColors.lightOnPrimaryContainer,
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2,
                        ),
                      ),
                      if (pendingPoints > 0) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),

                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                color: LightModeColors.warning,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l10n.pointsPendingApproval(pendingPoints),
                                style: GoogleFonts.inter(
                                  color: LightModeColors.warning,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      Material(
                        color: LightModeColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const PluxeeHistoryScreen(),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: LightModeColors.success.withValues(alpha: 0.2),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.history_rounded,
                                  color: LightModeColors.success,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  l10n.viewRedemptionHistory,
                                  style: GoogleFonts.inter(
                                    color: LightModeColors.success,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.redeemPluxeeCredits,
                        style: GoogleFonts.inter(
                          color: LightModeColors.dashboardTextPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),

                      // Info Card with Dark Layered Design
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: LightModeColors.warning,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: LightModeColors.lightOnPrimary
                                    .withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.card_giftcard_rounded,
                                size: 48,
                                color: LightModeColors.lightOnPrimary,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              l10n.howItWorks,
                              style: GoogleFonts.montserrat(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildInfoStep('1', l10n.choosePointsToConvert),
                            const SizedBox(height: 4),
                            _buildInfoStep('2', l10n.submitForReview),
                            const SizedBox(height: 4),
                            _buildInfoStep(
                              '3',
                              Localizations.localeOf(context).languageCode ==
                                      'fr'
                                  ? 'Votre demande sera prise en charge et une réponse vous sera communiquée sous 72 heures ouvrées.'
                                  : 'Your request will be processed and a response will be provided within 72 business hours.',
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: LightModeColors.lightOnPrimary
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: LightModeColors.lightOnPrimary
                                      .withValues(alpha: 0.2),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: LightModeColors.lightOnPrimary
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.info_rounded,
                                      size: 20,
                                      color: LightModeColors.lightOnPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      l10n.conversionRate(
                                        pluxeeProvider.conversionRate.toInt(),
                                      ),
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: LightModeColors.lightOnPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Redeem Button with Blue Gradient
                      Container(
                        decoration: BoxDecoration(
                          color: LightModeColors.lightError,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: availablePoints > 0
                                ? () => _showRedemptionDialog(context)
                                : null,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.card_giftcard_rounded,
                                    color: availablePoints > 0
                                        ? LightModeColors.lightOnPrimary
                                        : LightModeColors.lightSurfaceVariant,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    l10n.redeemPointsNow,
                                    style: GoogleFonts.inter(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: availablePoints > 0
                                          ? LightModeColors.lightOnPrimary
                                          : LightModeColors.lightSurfaceVariant,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: LightModeColors.lightOnPrimary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: GoogleFonts.inter(
                  color: LightModeColors.lightOnPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: LightModeColors.lightOnPrimary.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
