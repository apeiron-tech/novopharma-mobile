import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:novopharma/controllers/pluxee_redemption_provider.dart';
import 'package:novopharma/design/design.dart';
import 'package:novopharma/models/pluxee_redemption_request.dart';
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

  // The list arrives once. Rows built after the first screenful has landed
  // (scrolling back, rebuilds) appear in place instead of animating again.
  bool _arrived = false;

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
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: InkAppBar(
        title: l10n.redemptionHistory,
        onBack: () => Navigator.of(context).pop(),
      ),
      body: AppBackground(
        accent: Tone.amber,
        child: CustomScrollView(
          slivers: [
            // Content
            Consumer<PluxeeRedemptionProvider>(
              builder: (context, provider, child) {
                print(
                  '🖼️ [HistoryScreen] Building with ${provider.requests.length} requests, isLoading: ${provider.isLoading}',
                );

                if (provider.isLoading) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CapsuleLoader(),
                          const SizedBox(height: 16),
                          Text(
                            'Loading history...',
                            style: AppText.body(
                              size: 14,
                              color: AppColors.textMuted,
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
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: l10n.noRedemptionHistory,
                      message: l10n.noRedemptionHistoryMessage,
                      tone: Tone.amber,
                    ),
                  );
                }

                if (!_arrived) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _arrived = true,
                  );
                }

                return SliverPadding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 24),
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

    final hasReason = request.isRejected && request.rejectionReason != null;
    final stagger = !_arrived && index < 8;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Entrance(
        delay: stagger ? Duration(milliseconds: 60 * index) : Duration.zero,
        duration: stagger ? AppMotion.slow : Duration.zero,
        child: SoftCard(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          onTap: hasReason ? () => _toggleCardExpansion(request.id) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status badge and date
              Row(
                children: [
                  _buildModernStatusBadge(context, request),
                  const Spacer(),
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('MMM dd, yyyy').format(request.requestedAt),
                    style: AppText.label(size: 12.5, letterSpacing: 0),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Points and credits display
              _buildModernInfoRow(
                context,
                Icons.stars_rounded,
                l10n.pointsToRedeem,
                formatPoints(request.pointsToRedeem),
                Tone.amber,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, thickness: 1, color: AppColors.line),
              ),
              _buildModernInfoRow(
                context,
                Icons.card_giftcard_rounded,
                l10n.pluxeeCredits,
                request.pluxeeCreditsEquivalent.toStringAsFixed(2),
                Tone.mint,
              ),

              // Show rejection reason if rejected and expanded
              if (hasReason)
                AnimatedSize(
                  duration: AppMotion.medium,
                  curve: AppMotion.emphasized,
                  alignment: Alignment.topCenter,
                  child: _expandedCards.contains(request.id)
                      ? Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.coralTint,
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: AppColors.coralDeep,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      l10n.rejectionReason,
                                      style: AppText.label(
                                        size: 13.5,
                                        weight: FontWeight.w700,
                                        color: AppColors.coralDeep,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                request.rejectionReason!,
                                style: AppText.body(size: 13.5, height: 1.5),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.coralTint,
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                                color: AppColors.coralDeep,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.tapToViewReason,
                                  style: AppText.label(
                                    size: 12.5,
                                    weight: FontWeight.w700,
                                    color: AppColors.coralDeep,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.expand_more_rounded,
                                color: AppColors.coralDeep,
                              ),
                            ],
                          ),
                        ),
                ),
            ],
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

    Tone tone;
    IconData icon;
    String text;

    if (request.isPending) {
      tone = Tone.amber;
      icon = Icons.schedule_rounded;
      text = l10n.statusPending;
    } else if (request.isApproved) {
      tone = Tone.mint;
      icon = Icons.check_circle_rounded;
      text = l10n.statusApproved;
    } else {
      tone = Tone.coral;
      icon = Icons.cancel_rounded;
      text = l10n.statusRejected;
    }

    return TonePill(label: text, tone: tone, icon: icon);
  }

  Widget _buildModernInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Tone tone,
  ) {
    return Row(
      children: [
        TintIcon(icon: icon, tone: tone, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.label(size: 13, letterSpacing: 0),
          ),
        ),
        const SizedBox(width: 12),
        Text(value, style: AppText.display(size: 22)),
      ],
    );
  }
}
