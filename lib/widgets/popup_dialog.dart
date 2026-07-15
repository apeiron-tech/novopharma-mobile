import 'dart:async';
import 'package:flutter/material.dart';
import 'package:novopharma/models/popup_model.dart';
import 'package:novopharma/services/popup_service.dart';
import 'package:novopharma/theme.dart';
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
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();

    // Setup timer for the first popup if it has a duration
    _setupTimer(0);
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

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ScaleTransition(
        scale: _scaleAnimation,
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
                      height: MediaQuery.of(context).size.height * 0.7,
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
                      left: 10,
                      child: _AnimatingArrowButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        isLeft: true,
                        onPressed: () {
                          _carouselController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                    ),
                    Positioned(
                      right: 10,
                      child: _AnimatingArrowButton(
                        icon: Icons.arrow_forward_ios_rounded,
                        isLeft: false,
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
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: widget.popups.asMap().entries.map((entry) {
                    return GestureDetector(
                      onTap: () => _carouselController.animateToPage(entry.key),
                      child: Container(
                        width: 10.0,
                        height: 10.0,
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(
                            _currentIndex == entry.key ? 0.9 : 0.4,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopupCard(PopupModel popup, int index) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image part
                GestureDetector(
                  onTap: () => _handleTap(popup),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: popup.imageUrl.isNotEmpty
                        ? Image.network(
                            popup.imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: LightModeColors.lightSurfaceVariant,
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: LightModeColors.lightSurfaceVariant,
                                child: const Icon(
                                  Icons.broken_image,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: LightModeColors.lightPrimary,
                            child: const Icon(
                              Icons.campaign,
                              size: 80,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

                // Text details part
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Text(
                          popup.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: LightModeColors.dashboardTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(
                              popup.description,
                              style: const TextStyle(
                                fontSize: 14,
                                color: LightModeColors.dashboardTextSecondary,
                              ),
                              maxLines: popup.link.trim().isEmpty ? 5 : 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Action Button
                        if (popup.link.trim().isNotEmpty)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _handleTap(popup),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: LightModeColors.lightPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              child: const Text(
                                "En savoir plus",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Close button (X)
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: _close,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
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
                    color: LightModeColors.lightPrimary.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "$_remainingSeconds s",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void showPremiumPopup(BuildContext context, List<PopupModel> popups) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => PopupDialog(popups: popups),
  );
}

class _AnimatingArrowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isLeft;

  const _AnimatingArrowButton({
    required this.icon,
    required this.onPressed,
    required this.isLeft,
  });

  @override
  State<_AnimatingArrowButton> createState() => _AnimatingArrowButtonState();
}

class _AnimatingArrowButtonState extends State<_AnimatingArrowButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _translationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Subtle horizontal translate bounce
    _translationAnimation = Tween<double>(
      begin: 0.0,
      end: widget.isLeft ? -6.0 : 6.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _translationAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_translationAnimation.value, 0),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: GestureDetector(
              onTap: widget.onPressed,
              child: Icon(
                widget.icon,
                color: LightModeColors.novoPharmaBlue,
                size: 16,
              ),
            ),
          ),
        );
      },
    );
  }
}
