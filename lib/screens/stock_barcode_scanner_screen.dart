import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:novopharma/design/design.dart';

class StockBarcodeScannerScreen extends StatefulWidget {
  const StockBarcodeScannerScreen({super.key});

  @override
  State<StockBarcodeScannerScreen> createState() => _StockBarcodeScannerScreenState();
}

class _StockBarcodeScannerScreenState extends State<StockBarcodeScannerScreen> {
  final MobileScannerController cameraController = MobileScannerController();
  bool _isDetecting = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isDetecting) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        setState(() {
          _isDetecting = true;
        });

        // Light haptic feedback
        HapticFeedback.lightImpact();

        // Stop camera and pop raw value
        cameraController.stop();
        Navigator.pop(context, barcode.rawValue);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Camera preview, full-bleed
            MobileScanner(controller: cameraController, onDetect: _onDetect),

            // Ink scrim with the scan window cut out of it, and the hint
            Positioned.fill(
              child: _ScanChrome(
                detected: _isDetecting,
                hint:
                    "Placez le code-barres du produit dans le cadre pour le scanner automatiquement",
              ),
            ),

            // Top chrome: close + what this scanner is for
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      GlassIconButton(
                        icon: Icons.close_rounded,
                        tooltip:
                            MaterialLocalizations.of(context).closeButtonTooltip,
                        size: 48,
                        onTap: () => Navigator.maybePop(context),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          "Scanner le code SKU",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.display(size: 20, color: Colors.white),
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

/// Everything drawn over the camera: the ink scrim, the scan window with its
/// mint brackets and the hint underneath. Kept still on purpose — stock
/// taking is a long, repetitive task.
class _ScanChrome extends StatelessWidget {
  final bool detected;
  final String hint;

  const _ScanChrome({required this.detected, required this.hint});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final side = math.min(268.0, size.width - 72);
        final window = Rect.fromCenter(
          center: Offset(size.width / 2, size.height * 0.44),
          width: side,
          height: side,
        );

        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _ScanWindowPainter(window: window),
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
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          detected
                              ? Icons.check_circle_rounded
                              : Icons.qr_code_scanner_rounded,
                          color: AppColors.mintBright,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            hint,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(
                              size: 14.5,
                              weight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.3,
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

  const _ScanWindowPainter({required this.window});

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

  @override
  bool shouldRepaint(_ScanWindowPainter oldDelegate) =>
      oldDelegate.window != window;
}
