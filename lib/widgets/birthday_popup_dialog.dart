import 'dart:async';
import 'package:flutter/material.dart';
import 'package:novopharma/theme.dart';

class BirthdayPopupDialog extends StatefulWidget {
  final String title;
  final String description;
  final num? points;

  const BirthdayPopupDialog({
    super.key,
    required this.title,
    required this.description,
    this.points,
  });

  @override
  State<BirthdayPopupDialog> createState() => _BirthdayPopupDialogState();
}

class _BirthdayPopupDialogState extends State<BirthdayPopupDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _countdownTimer;
  int _remainingSeconds = 10;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _animController.forward();
    _startTimer();
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingSeconds > 1) {
            _remainingSeconds--;
          } else {
            _remainingSeconds = 0;
            timer.cancel();
            _close();
          }
        });
      }
    });
  }

  void _close() {
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final dialogWidth = mediaQuery.size.width * 0.85;

    return Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: dialogWidth,
              constraints: const BoxConstraints(maxWidth: 380),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Inner content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Timer badge top-left inside
                        Align(
                          alignment: Alignment.topLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: LightModeColors.lightPrimary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 14,
                                  color: LightModeColors.lightPrimary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$_remainingSeconds s',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: LightModeColors.lightPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Animated / Colorful Birthday Icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFF758C),
                                Color(0xFFFF7EB3),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF758C).withOpacity(0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.cake_rounded,
                              size: 42,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Title
                        Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: LightModeColors.dashboardTextPrimary,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Description
                        Text(
                          widget.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: LightModeColors.dashboardTextPrimary
                                .withOpacity(0.75),
                            height: 1.4,
                          ),
                        ),

                        // Optional Points Badge
                        if (widget.points != null && widget.points! > 0) ...[
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF10B981),
                                  Color(0xFF059669),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.stars_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '+${widget.points} points bonus !',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Close button "X" on top-right
                  Positioned(
                    top: 14,
                    right: 14,
                    child: GestureDetector(
                      onTap: _close,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Colors.black87,
                        ),
                      ),
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
}

Future<void> showBirthdayPopupDialog({
  required BuildContext context,
  required String title,
  required String description,
  num? points,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => BirthdayPopupDialog(
      title: title,
      description: description,
      points: points,
    ),
  );
}
