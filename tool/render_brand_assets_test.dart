// Renders the logo PNGs from the same painter the app uses.
//
//   flutter test tool/render_brand_assets_test.dart
//
// Then regenerate the native icons and launch screens:
//
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novopharma/design/brand.dart';

Future<void> _render(
  WidgetTester tester,
  String path,
  int size,
  void Function(Canvas canvas, Rect rect) paint,
) async {
  await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final rect = Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());
    final canvas = Canvas(recorder, rect);
    paint(canvas, rect);
    final image = await recorder.endRecording().toImage(size, size);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(path)..createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('render brand assets', (tester) async {
    // App icon: full-bleed tile, no transparency.
    for (final path in [
      'assets/app_icon.png',
      'assets/logo/logo.png',
      'assets/images/logo.png',
    ]) {
      await _render(tester, path, 1024, (c, r) => paintBrandTile(c, r));
    }

    // Mark only, transparent, for ink surfaces.
    await _render(
      tester,
      'assets/logo/whiteLogo.png',
      1024,
      (c, r) => BrandMarkPainter.paintMark(c, r),
    );

    // Mark only, transparent, for light surfaces.
    await _render(
      tester,
      'assets/logo/blueLogo.png',
      1024,
      (c, r) => BrandMarkPainter.paintMark(c, r, onDark: false),
    );

    // Native launch screen (source is treated as 4x: shows at 132pt).
    await _render(
      tester,
      'assets/logo/splashMark.png',
      528,
      (c, r) => BrandMarkPainter.paintMark(c, r),
    );

    // Android 12+ launch icon: content must sit inside the centre circle.
    await _render(
      tester,
      'assets/logo/splashMarkAndroid12.png',
      1152,
      (c, r) => BrandMarkPainter.paintMark(c, r.deflate(1152 * 0.24)),
    );
  });
}
