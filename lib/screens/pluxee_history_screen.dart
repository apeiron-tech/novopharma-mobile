import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:novopharma/controllers/pluxee_redemption_provider.dart';
import 'package:novopharma/models/pluxee_redemption_request.dart';
import 'package:novopharma/theme.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';

class PluxeeHistoryScreen extends StatefulWidget {
  const PluxeeHistoryScreen({super.key});

  @override
  State<PluxeeHistoryScreen> createState() => _PluxeeHistoryScreenState();
}

class _PluxeeHistoryScreenState extends State<PluxeeHistoryScreen> {
  // Track which cards are expanded
  final Set<String> _expandedCards = {};

  void _toggleCardExpansion(String requestId) {
    setState(() {
      if (_expandedCards.contains(requestId)) {
        _expandedCards.remove(requestId);
      } else {
        _expandedCards.add(requestId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: // Modern App Bar with simpler design
          AppBar(

            backgroundColor: LightModeColors.lightPrimary,
            surfaceTintColor: Colors.transparent,
            // App bar title and back button
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(20),
              child: Container(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Row(
                  children: [
                    // Back button with standard styling
                    Container(
                      decoration: BoxDecoration(
                        color: LightModeColors.lightOnPrimary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: LightModeColors.lightOnPrimary.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: LightModeColors.lightOnPrimary,
                          size: 16,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: const EdgeInsets.all(2),
                        splashRadius: 20,
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Title
                    Expanded(
                      child: Text(
                        l10n.redemptionHistory,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: LightModeColors.lightOnPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      backgroundColor: LightModeColors.lightBackground,
      body: CustomScrollView(
        slivers: [
          

          // Content
          Consumer<PluxeeRedemptionProvider>(
            builder: (context, provider, child) {
              print(
                '🖼️ [HistoryScreen] Building with ${provider.requests.length} requests, isLoading: ${provider.isLoading}',
              );

              if (provider.isLoading) {
                return SliverFillRemaining(
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.all(32),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: LightModeColors.lightSurface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: LightModeColors.lightSurfaceVariant.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: LightModeColors.lightPrimary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading history...',
                            style: TextStyle(
                              color: LightModeColors.dashboardTextSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              if (provider.requests.isEmpty) {
                print('⚠️ [HistoryScreen] No requests to display');
                return SliverFillRemaining(
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.all(32),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: LightModeColors.lightSurface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: LightModeColors.lightSurfaceVariant.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: LightModeColors.warning.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Icon(
                              Icons.receipt_long_outlined,
                              size: 48,
                              color: LightModeColors.warning,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.noRedemptionHistory,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: LightModeColors.dashboardTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              l10n.noRedemptionHistoryMessage,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: LightModeColors.dashboardTextSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final request = provider.requests[index];
                    return _buildEnhancedRequestCard(context, request, index);
                  }, childCount: provider.requests.length),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedRequestCard(
    BuildContext context,
    PluxeeRedemptionRequest request,
    int index,
  ) {
    final l10n = AppLocalizations.of(context)!;
    print('🖼️ [HistoryScreen] Building card for request ${request.id}');

    // Stagger animation delay
    final delay = Duration(milliseconds: 50 * index);

    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 400) + delay,
      curve: Curves.easeOutCubic,
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: InkWell(
        onTap: request.isRejected && request.rejectionReason != null
            ? () => _toggleCardExpansion(request.id)
            : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: LightModeColors.lightSurface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: request.isPending
                    ? LightModeColors.warning.withValues(alpha: 0.1)
                    : request.isApproved
                    ? LightModeColors.success.withValues(alpha: 0.1)
                    : LightModeColors.lightError.withValues(alpha: 0.1),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                color: LightModeColors.lightSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: LightModeColors.lightOnPrimary.withValues(alpha: 0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: LightModeColors.lightSurfaceVariant.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Colored accent bar on the left
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 6,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: request.isPending
                              ? [LightModeColors.warning, LightModeColors.warning]
                              : request.isApproved
                              ? [LightModeColors.success, LightModeColors.success]
                              : [
                                  LightModeColors.lightError,
                                  LightModeColors.lightError,
                                ],
                        ),
                      ),
                    ),
                  ),

                  // Main content
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with status badge and date
                        Row(
                          children: [
                            Expanded(
                              child: _buildModernStatusBadge(context, request),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: LightModeColors.lightSurfaceVariant.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 14,
                                    color: LightModeColors.dashboardTextSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    DateFormat(
                                      'MMM dd, yyyy',
                                    ).format(request.requestedAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: LightModeColors.dashboardTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Points and credits display
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: LightModeColors.novoPharmaBlue.withValues(
                              alpha: 0.05,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: LightModeColors.novoPharmaBlue.withValues(
                                alpha: 0.1,
                              ),
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildModernInfoRow(
                                context,
                                Icons.stars_rounded,
                                l10n.pointsToRedeem,
                                '${request.pointsToRedeem}',
                                LightModeColors.warning,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        height: 1,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              LightModeColors.dashboardTextSecondary.withValues(alpha: 0.1),
                                              LightModeColors.dashboardTextSecondary.withValues(alpha: 0.3),
                                              LightModeColors.dashboardTextSecondary.withValues(alpha: 0.1),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Icon(
                                        Icons.arrow_downward_rounded,
                                        size: 16,
                                        color: LightModeColors
                                            .dashboardTextSecondary,
                                      ),
                                    ),
                                    Expanded(
                                      child: Container(
                                        height: 1,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              LightModeColors.dashboardTextSecondary.withValues(alpha: 0.1),
                                              LightModeColors.dashboardTextSecondary.withValues(alpha: 0.3),
                                              LightModeColors.dashboardTextSecondary.withValues(alpha: 0.1),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildModernInfoRow(
                                context,
                                Icons.card_giftcard_rounded,
                                l10n.pluxeeCredits,
                                '${request.pluxeeCreditsEquivalent.toStringAsFixed(2)}',
                                LightModeColors.success,
                              ),
                            ],
                          ),
                        ),

                        // Show rejection reason if rejected and expanded
                        if (request.isRejected &&
                            request.rejectionReason != null)
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: _expandedCards.contains(request.id)
                                ? Container(
                                    margin: const EdgeInsets.only(top: 16),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: LightModeColors.lightSurfaceVariant.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: LightModeColors.lightError.withValues(alpha: 0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: LightModeColors.lightError.withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: const Icon(
                                                Icons.error_outline,
                                                color: LightModeColors.lightError,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                l10n.rejectionReason,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: LightModeColors.lightError,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          request.rejectionReason!,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: LightModeColors.lightError,
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Container(
                                    margin: const EdgeInsets.only(top: 16),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: LightModeColors.lightSurfaceVariant.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: LightModeColors.lightError.withValues(alpha: 0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          size: 18,
                                          color: LightModeColors.lightError,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            l10n.tapToViewReason,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: LightModeColors.lightError,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_drop_down,
                                          color: LightModeColors.lightError,
                                        ),
                                      ],
                                    ),
                                  ),
                          )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernStatusBadge(
    BuildContext context,
    PluxeeRedemptionRequest request,
  ) {
    final l10n = AppLocalizations.of(context)!;

    Color bgColor;
    Color iconColor;
    Color textColor;
    IconData icon;
    String text;

    if (request.isPending) {
      bgColor = LightModeColors.warningContainer;
      iconColor = LightModeColors.warning;
      textColor = LightModeColors.warning;
      icon = Icons.schedule_rounded;
      text = l10n.statusPending;
    } else if (request.isApproved) {
      bgColor = LightModeColors.successContainer;
      iconColor = LightModeColors.success;
      textColor = LightModeColors.success;
      icon = Icons.check_circle_rounded;
      text = l10n.statusApproved;
    } else {
      bgColor = LightModeColors.warningContainer;
      iconColor = LightModeColors.lightError;
      textColor = LightModeColors.lightError;
      icon = Icons.cancel_rounded;
      text = l10n.statusRejected;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            iconColor.withValues(alpha: 0.1),
            iconColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: iconColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color accentColor,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: accentColor, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: LightModeColors.dashboardTextSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: LightModeColors.dashboardTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

}
