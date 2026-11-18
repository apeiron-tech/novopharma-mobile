import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:novopharma/design/design.dart';
import 'package:novopharma/models/popup_model.dart';
import 'package:novopharma/services/popup_service.dart';
import 'package:carousel_slider/carousel_slider.dart';

class PopupDialog extends StatefulWidget {
  final List<PopupModel> popups;

  const PopupDialog({super.key, required this.popups});

  @override
  State<PopupDialog> createState() => _PopupDialogState();
}

class _PopupDialogState extends State<PopupDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  Timer? _displayTimer;
  int? _remainingSeconds;
  int _currentIndex = 0;
  final CarouselSliderController _carouselController =
      CarouselSliderController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.slow,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.emphasized,
    );
    _controller.forward();

    // Setup timer for the first popup if it has a duration
    _setupTimer(0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The card rises into place; with reduced motion it is simply there.
    if (AppMotion.reduced(context)) _controller.value = 1;
  }

  void _setupTimer(int index) {
    _displayTimer?.cancel();
    if (widget.popups[index].displayDuration != null) {
      _remainingSeconds = widget.popups[index].displayDuration;
      _displayTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            if (_remainingSeconds! > 0) {
              _remainingSeconds = _remainingSeconds! - 1;
            } else {
              timer.cancel();
              if (_currentIndex < widget.popups.length - 1) {
                _carouselController.nextPage();
              } else {
                _close();
              }
            }
          });
        }
      });
    } else {
      if (mounted) {
        setState(() {
          _remainingSeconds = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _displayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _close() {
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _handleTap(PopupModel popup) {
    _close();
    PopupService.handleRedirection(context, popup.link);
  }

  /// The height every card is laid out for. Slightly taller than before so
  /// the text under a square image keeps room on short phones.
  double _carouselHeight(BuildContext context) =>
      MediaQuery.of(context).size.height * 0.74;

  @override
  Widget build(BuildContext context) {
    final count = widget.popups.length;

    return Center(
      // Rises out of the page: lifts and grows into place. The route's own
      // fade handles opacity, so the frost stays live throughout.
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          final t = _scaleAnimation.value;
          return Transform.translate(
            offset: Offset(0, 56 * (1 - t)),
            child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  CarouselSlider.builder(
                    carouselController: _carouselController,
                    itemCount: widget.popups.length,
                    options: CarouselOptions(
                      height: _carouselHeight(context),
                      viewportFraction: 0.78,
                      enlargeCenterPage: true,
                      enableInfiniteScroll: widget.popups.length > 1,
                      onPageChanged: (index, reason) {
                        setState(() {
                          _currentIndex = index;
                        });
                        _setupTimer(index);
                      },
                    ),
                    itemBuilder: (context, index, realIndex) {
                      final popup = widget.popups[index];
                      return _buildPopupCard(popup, index);
                    },
                  ),
                  if (widget.popups.length > 1) ...[
                    Positioned(
                      left: 4,
                      child: _CarouselArrow(
                        icon: Icons.chevron_left_rounded,
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).previousPageTooltip,
                        onPressed: () {
                          _carouselController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                    ),
                    Positioned(
                      right: 4,
                      child: _CarouselArrow(
                        icon: Icons.chevron_right_rounded,
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).nextPageTooltip,
                        onPressed: () {
                          _carouselController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
              if (widget.popups.length > 1) ...[
                const SizedBox(height: 8),
                _buildDots(count),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Page indicator: small capsules on a glass pill, the current one
  /// stretched out in indigo. Each keeps a full-height tap target.
  Widget _buildDots(int count) {
    const idle = 8.0;
    const active = 24.0;
    const gap = 10.0;
    final rowWidth = (count - 1) * (idle + gap) + (active + gap);

    return SizedBox(
      height: 44,
      width: rowWidth + 16,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Glass(
            height: 26,
            width: rowWidth + 16,
            shadow: false,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: const SizedBox.expand(),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: widget.popups.asMap().entries.map((entry) {
              final selected = _currentIndex == entry.key;
              return Pressable(
                onTap: () => _carouselController.animateToPage(entry.key),
                pressedScale: 0.85,
                semanticLabel: '${entry.key + 1} / $count',
                child: AnimatedContainer(
                  duration: AppMotion.medium,
                  curve: AppMotion.emphasized,
                  width: (selected ? active : idle) + gap,
                  height: 44,
                  alignment: Alignment.center,
                  child: AnimatedContainer(
                    duration: AppMotion.medium,
                    curve: AppMotion.emphasized,
                    width: selected ? active : idle,
                    height: 8,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.indigo
                          : AppColors.ink.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPopupCard(PopupModel popup, int index) {
    final hasLink = popup.link.trim().isNotEmpty;

    // The carousel hands its side pages a shorter box and then scales them
    // down as well. Laying every card out at the full height keeps the side
    // pages exact, smaller copies of the centre one instead of squeezing
    // their content.
    return OverflowBox(
      minHeight: 0,
      maxHeight: _carouselHeight(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The image is square whenever the screen allows it; on
                // short or wide screens it gives height back to the text.
                const frame = 8.0;
                final imageSide = constraints.maxWidth - frame * 2;
                final roomForImage =
                    constraints.maxHeight - frame * 3 - (hasLink ? 176 : 120);
                final imageHeight = math.max(
                  0.0,
                  math.min(imageSide, roomForImage),
                );

                return Glass(
                  blur: Glass.frost,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  padding: const EdgeInsets.all(frame),
                  child: Stack(
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Image part
                          Pressable(
                            onTap: () => _handleTap(popup),
                            pressedScale: 0.985,
                            semanticLabel: popup.title,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadii.lg),
                              child: SizedBox(
                                height: imageHeight,
                                child: _buildImage(popup),
                              ),
                            ),
                          ),
                          const SizedBox(height: frame),

                          // Text details part
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                14,
                                16,
                                14,
                              ),
                              decoration: BoxDecoration(
                                // A veil of white under the words so they
                                // stay crisp whatever shows through.
                                color: Colors.white.withValues(alpha: 0.58),
                                borderRadius: BorderRadius.circular(
                                  AppRadii.lg,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Flexible(
                                    child: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                            popup.title,
                                            style: AppText.display(size: 21),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            popup.description,
                                            style: AppText.body(
                                              size: 14.5,
                                              height: 1.45,
                                            ),
                                            maxLines: popup.link.trim().isEmpty
                                                ? 5
                                                : 4,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Action Button
                                  if (popup.link.trim().isNotEmpty) ...[
                                    const SizedBox(height: 14),
                                    PrimaryButton(
                                      label: "En savoir plus",
                                      icon: Icons.arrow_forward_rounded,
                                      height: 48,
                                      onPressed: () => _handleTap(popup),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Close button (X)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: _CloseButton(onTap: _close),
                      ),

                      // Timer badge if duration exists and it's the current page
                      if (_remainingSeconds != null && _currentIndex == index)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.ink.withValues(alpha: 0.62),
                              borderRadius: BorderRadius.circular(
                                AppRadii.pill,
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.28),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.timer_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "$_remainingSeconds s",
                                  style: AppText.display(
                                    size: 13,
                                    color: Colors.white,
                                    letterSpacing: 0,
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
        ),
      ),
    );
  }

  Widget _buildImage(PopupModel popup) {
    if (popup.imageUrl.isEmpty) {
      return const DecoratedBox(
        decoration: BoxDecoration(gradient: AppGradients.indigo),
        child: Center(
          child: Icon(Icons.campaign_rounded, size: 80, color: Colors.white),
        ),
      );
    }
    return Image.network(
      popup.imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const ColoredBox(
          color: AppColors.indigoTint,
          child: Center(child: CapsuleLoader()),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return const ColoredBox(
          color: AppColors.indigoTint,
          child: Center(
            child: Icon(
              Icons.broken_image_rounded,
              size: 50,
              color: AppColors.indigo,
            ),
          ),
        );
      },
    );
  }
}

Future<void> showPremiumPopup(BuildContext context, List<PopupModel> popups) async {
  await showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: AppColors.ink.withValues(alpha: 0.6),
    builder: (context) => PopupDialog(popups: popups),
  );
}

/// The round dismiss control that sits on the image: smoked glass so it
/// reads on any picture, with a full-size tap target around it.
class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = MaterialLocalizations.of(context).closeButtonTooltip;
    return Tooltip(
      message: label,
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.9,
        semanticLabel: label,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.62),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Previous / next, floating at the carousel's edges.
class _CarouselArrow extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _CarouselArrow({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onPressed,
        pressedScale: 0.9,
        semanticLabel: tooltip,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                shape: BoxShape.circle,
                boxShadow: AppShadows.card,
              ),
              child: Icon(icon, color: AppColors.indigo, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}
