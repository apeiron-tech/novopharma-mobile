import 'dart:async';
import 'package:flutter/material.dart';
import 'package:novopharma/design/design.dart';

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
      curve: AppMotion.spring,
    );

    _animController.forward();
    _startTimer();

    // This popup is itself the earned moment: shower it once, as it opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) celebrate(context);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) _animController.value = 1;
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
    final closeLabel = MaterialLocalizations.of(context).closeButtonTooltip;

    return Center(
      // Pops up with a little overshoot. The route's own fade handles
      // opacity, so the frost stays live while it grows.
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.86, end: 1).animate(_scaleAnimation),
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 380,
              maxHeight: mediaQuery.size.height * 0.82,
            ),
            child: Glass(
              blur: Glass.frost,
              width: dialogWidth,
              borderRadius: BorderRadius.circular(AppRadii.xl),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Timer badge on the left, close button "X" on the right
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: TonePill(
                            label: '$_remainingSeconds s',
                            tone: Tone.amber,
                            icon: Icons.timer_rounded,
                          ),
                        ),
                        const Spacer(),
                        Tooltip(
                          message: closeLabel,
                          child: Pressable(
                            onTap: _close,
                            pressedScale: 0.9,
                            semanticLabel: closeLabel,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.ink.withValues(alpha: 0.07),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 22,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Birthday icon: a coral dome in an amber halo
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.amberTint,
                        border: Border.all(
                          color: AppColors.amber.withValues(alpha: 0.45),
                          width: 1.5,
                        ),
                      ),
                      child: const BlisterIcon(
                        icon: Icons.cake_rounded,
                        tone: Tone.coral,
                        size: 84,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: AppText.display(size: 25, height: 1.15),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Description
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        widget.description,
                        textAlign: TextAlign.center,
                        style: AppText.body(size: 15, height: 1.45),
                      ),
                    ),

                    // Optional Points Badge
                    if (widget.points != null && widget.points! > 0) ...[
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppGradients.amber,
                            borderRadius: BorderRadius.circular(AppRadii.lg),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                            boxShadow: AppShadows.glow(
                              AppColors.amber,
                              strength: 0.32,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.stars_rounded,
                                      color: AppColors.ink,
                                      size: 30,
                                    ),
                                    const SizedBox(width: 8),
                                    CountUp(
                                      value: widget.points!,
                                      format: (v) => '+${formatPoints(v)}',
                                      style: AppText.display(
                                        size: 46,
                                        weight: FontWeight.w800,
                                        color: AppColors.ink,
                                        height: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'points bonus !',
                                textAlign: TextAlign.center,
                                style: AppText.body(
                                  size: 15,
                                  weight: FontWeight.w700,
                                  color: AppColors.ink,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
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
    barrierColor: AppColors.ink.withValues(alpha: 0.55),
    builder: (context) => BirthdayPopupDialog(
      title: title,
      description: description,
      points: points,
    ),
  );
}
