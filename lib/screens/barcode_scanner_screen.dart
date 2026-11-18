import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:novopharma/design/design.dart';
import 'package:novopharma/screens/product_screen.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';
import 'dart:developer';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isDetecting = false;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isDetecting) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        // Log the scanned barcode
        log('Barcode scanned: ${barcode.rawValue}');

        setState(() {
          _isDetecting = true;
        });

        // Light haptic feedback
        HapticFeedback.lightImpact();

        // Stop camera
        cameraController.stop();

        // Debounce for 1.2 seconds
        _debounceTimer = Timer(const Duration(milliseconds: 1200), () {
          // Navigate to Product screen with barcode data
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => ProductScreen(sku: barcode.rawValue!),
            ),
          );
        });
        break;
      }
    }
  }

  void _toggleFlash() {
    cameraController.toggleTorch();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Camera preview, full-bleed
            MobileScanner(controller: cameraController, onDetect: _onDetect),

            // Ink scrim with the scan window cut out of it
            Positioned.fill(
              child: _ScanOverlay(
                active: !_isDetecting,
                hint: l10n.scanBarcodeHere,
              ),
            ),

            // Top overlay with controls
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Close button
                      GlassIconButton(
                        icon: Icons.close_rounded,
                        tooltip: l10n.close,
                        size: 48,
                        onTap: () => Navigator.of(context).pop(),
                      ),

                      // Flash toggle
                      ValueListenableBuilder<MobileScannerState>(
                        valueListenable: cameraController,
                        builder: (context, state, _) => GlassIconButton(
                          icon: state.torchState == TorchState.on
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          tooltip: 'Flash',
                          size: 48,
                          onTap: _toggleFlash,
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
    );
  }
}

/// Everything drawn over the camera: the scrim, the scan window with its
/// mint brackets, the sweeping line that says the scanner is live, and the
/// hint underneath.
class _ScanOverlay extends StatefulWidget {
  final bool active;
  final String hint;

  const _ScanOverlay({required this.active, required this.hint});

  @override
  State<_ScanOverlay> createState() => _ScanOverlayState();
}

class _ScanOverlayState extends State<_ScanOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  void _sync() {
    final run = widget.active && !AppMotion.reduced(context);
    if (run && !_sweep.isAnimating) {
      _sweep.repeat();
    } else if (!run && _sweep.isAnimating) {
      _sweep.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_ScanOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final side = math.min(268.0, size.width - 72);
        final window = Rect.fromCenter(
          center: Offset(size.width / 2, size.height * 0.46),
          width: side,
          height: side,
        );

        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _ScanWindowPainter(
                      window: window,
                      sweep: _sweep,
                      showLine: widget.active && !AppMotion.reduced(context),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: window.bottom + 28,
              left: 24,
              right: 24,
              child: IgnorePointer(
                child: Center(
                  child: Glass(
                    style: GlassStyle.smoked,
                    blur: Glass.frost,
                    shadow: false,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.active
                              ? Icons.qr_code_scanner_rounded
                              : Icons.check_circle_rounded,
                          color: AppColors.mintBright,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            widget.hint,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(
                              size: 15,
                              weight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScanWindowPainter extends CustomPainter {
  final Rect window;
  final Animation<double> sweep;
  final bool showLine;

  _ScanWindowPainter({
    required this.window,
    required this.sweep,
    required this.showLine,
  }) : super(repaint: sweep);

  static const double _radius = AppRadii.lg;
  static const double _arm = 46;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      window,
      const Radius.circular(_radius),
    );

    // The scrim, with the window cut out of it.
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRRect(rrect),
      Paint()..color = AppColors.ink.withValues(alpha: 0.66),
    );

    // A faint rim so the window reads as a pane of glass.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.26),
    );

    if (showLine) _paintSweep(canvas, rrect);

    // Mint brackets hugging each corner.
    const r = Radius.circular(_radius);
    final l = window.left, t = window.top, rt = window.right, b = window.bottom;
    final brackets = Path()
      ..moveTo(l, t + _arm)
      ..lineTo(l, t + _radius)
      ..arcToPoint(Offset(l + _radius, t), radius: r)
      ..lineTo(l + _arm, t)
      ..moveTo(rt - _arm, t)
      ..lineTo(rt - _radius, t)
      ..arcToPoint(Offset(rt, t + _radius), radius: r)
      ..lineTo(rt, t + _arm)
      ..moveTo(rt, b - _arm)
      ..lineTo(rt, b - _radius)
      ..arcToPoint(Offset(rt - _radius, b), radius: r)
      ..lineTo(rt - _arm, b)
      ..moveTo(l + _arm, b)
      ..lineTo(l + _radius, b)
      ..arcToPoint(Offset(l, b - _radius), radius: r)
      ..lineTo(l, b - _arm);

    canvas.drawPath(
      brackets,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..color = AppColors.mint.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      brackets,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round
        ..color = AppColors.mintBright,
    );
  }

  void _paintSweep(Canvas canvas, RRect rrect) {
    const inset = 14.0;
    const trail = 54.0;
    final t = Curves.easeInOut.transform(sweep.value);
    // Fades in at the top and out at the bottom so the loop never snaps.
    final strength = math.sin(math.pi * sweep.value).clamp(0.0, 1.0);
    final y = window.top + inset + (window.height - inset * 2) * t;
    final left = window.left + inset;
    final right = window.right - inset;

    canvas.save();
    canvas.clipRRect(rrect);

    final trailRect = Rect.fromLTRB(left, y - trail, right, y);
    canvas.drawRect(
      trailRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.mint.withValues(alpha: 0),
            AppColors.mint.withValues(alpha: 0.24 * strength),
          ],
        ).createShader(trailRect),
    );

    final lineRect = Rect.fromLTRB(left, y - 1.5, right, y + 1.5);
    final lineShader = LinearGradient(
      colors: [
        AppColors.mintBright.withValues(alpha: 0),
        AppColors.mintBright.withValues(alpha: strength),
        AppColors.mintBright.withValues(alpha: strength),
        AppColors.mintBright.withValues(alpha: 0),
      ],
      stops: const [0, 0.18, 0.82, 1],
    ).createShader(lineRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(lineRect.inflate(2), const Radius.circular(4)),
      Paint()
        ..shader = lineShader
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(lineRect, const Radius.circular(2)),
      Paint()..shader = lineShader,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScanWindowPainter oldDelegate) =>
      oldDelegate.window != window || oldDelegate.showLine != showLine;
}
