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
      backgroundColor: LightModeColors.novoPharmaLightBlue,
      body: CustomScrollView(
        slivers: [
          // Modern App Bar with gradient
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF074F75), Color(0xFF1F9BD1)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.history,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              l10n.redemptionHistory,
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content
          Consumer<PluxeeRedemptionProvider>(
            builder: (context, provider, child) {
              print(
                '🖼️ [HistoryScreen] Building with ${provider.requests.length} requests, isLoading: ${provider.isLoading}',
              );

              if (provider.isLoading) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: LightModeColors.novoPharmaBlue,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading history...',
                          style: GoogleFonts.inter(
                            color: LightModeColors.dashboardTextSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (provider.requests.isEmpty) {
                print('⚠️ [HistoryScreen] No requests to display');
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: LightModeColors.novoPharmaBlue
                                    .withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: LightModeColors.novoPharmaBlue.withOpacity(
                              0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          l10n.noRedemptionHistory,
                          style: GoogleFonts.montserrat(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: LightModeColors.dashboardTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            l10n.noRedemptionHistoryMessage,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: LightModeColors.dashboardTextSecondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: request.isPending
                    ? const Color(0xFFF59E0B).withOpacity(0.1)
                    : request.isApproved
                    ? const Color(0xFF10B981).withOpacity(0.1)
                    : const Color(0xFFEF4444).withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
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
                            ? [const Color(0xFFF59E0B), const Color(0xFFFBBF24)]
                            : request.isApproved
                            ? [const Color(0xFF10B981), const Color(0xFF34D399)]
                            : [
                                const Color(0xFFEF4444),
                                const Color(0xFFF87171),
                              ],
                      ),
                    ),
                  ),
                ),

                // Main content
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
                              color: LightModeColors.novoPharmaLightBlue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: LightModeColors.dashboardTealBlue,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  DateFormat(
                                    'MMM dd, yyyy',
                                  ).format(request.requestedAt),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: LightModeColors.dashboardTealBlue,
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
                          color: LightModeColors.novoPharmaLightBlue,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            _buildModernInfoRow(
                              context,
                              Icons.stars_rounded,
                              l10n.pointsToRedeem,
                              '${request.pointsToRedeem}',
                              const Color(0xFFF59E0B),
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
                                            Colors.grey.withOpacity(0.1),
                                            Colors.grey.withOpacity(0.3),
                                            Colors.grey.withOpacity(0.1),
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
                                            Colors.grey.withOpacity(0.1),
                                            Colors.grey.withOpacity(0.3),
                                            Colors.grey.withOpacity(0.1),
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
                              const Color(0xFF10B981),
                            ),
                          ],
                        ),
                      ),

                      // Show rejection reason if rejected and expanded
                      if (request.isRejected &&
                          request.rejectionReason != null) ...[
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: _expandedCards.contains(request.id)
                              ? Container(
                                  margin: const EdgeInsets.only(top: 16),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFFFEF2F2),
                                        const Color(0xFFFEE2E2),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(
                                        0xFFFCA5A5,
                                      ).withOpacity(0.5),
                                      width: 1.5,
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
                                              color: const Color(
                                                0xFFEF4444,
                                              ).withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Icon(
                                              Icons.error_outline,
                                              color: Color(0xFFEF4444),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              l10n.rejectionReason,
                                              style: GoogleFonts.montserrat(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFFEF4444),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        request.rejectionReason!,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: const Color(0xFF991B1B),
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
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(
                                        0xFFFCA5A5,
                                      ).withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 18,
                                        color: const Color(0xFFEF4444),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          l10n.tapToViewReason,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: const Color(0xFFEF4444),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_drop_down,
                                        color: const Color(0xFFEF4444),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
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
      bgColor = const Color(0xFFFFF7ED);
      iconColor = const Color(0xFFF59E0B);
      textColor = const Color(0xFFF59E0B);
      icon = Icons.schedule_rounded;
      text = l10n.statusPending;
    } else if (request.isApproved) {
      bgColor = const Color(0xFFECFDF5);
      iconColor = const Color(0xFF10B981);
      textColor = const Color(0xFF10B981);
      icon = Icons.check_circle_rounded;
      text = l10n.statusApproved;
    } else {
      bgColor = const Color(0xFFFEF2F2);
      iconColor = const Color(0xFFEF4444);
      textColor = const Color(0xFFEF4444);
      icon = Icons.cancel_rounded;
      text = l10n.statusRejected;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.2), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: textColor,
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: accentColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: LightModeColors.dashboardTextSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.montserrat(
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

  void _showRejectionReasonDialog(
    BuildContext context,
    PluxeeRedemptionRequest request,
  ) {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 10,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFEF2F2), Colors.white],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFEF4444),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      l10n.rejectionReason,
                      style: GoogleFonts.montserrat(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Divider
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.grey.withOpacity(0.0),
                      Colors.grey.withOpacity(0.3),
                      Colors.grey.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Rejection reason content
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFCA5A5).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  request.rejectionReason ?? l10n.noReasonProvided,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF991B1B),
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    l10n.close,
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
