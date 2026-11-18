import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' as mui;
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../design/glass.dart';
import '../design/tokens.dart';

/// The ink glass frame every in-page video sits in: a smoked pane with the
/// video set into it like a screen in its bezel, so a player reads as one
/// object on the pastel canvas instead of a black hole in the page.
///
/// No blur: the frame rests on the page and scrolls with it.
///
/// On phones the YouTube surface is drawn in the app overlay, above this
/// widget, so it cannot be clipped from here. The bezel is therefore wide
/// enough for a square-cornered video to sit wholly inside the frame's
/// rounded corners; anything drawn in place (the native player, loading and
/// error states) also gets its own corners rounded.
class PlayerFrame extends StatelessWidget {
  const PlayerFrame({super.key, required this.child});

  final Widget child;

  static const double _bezel = 8;

  @override
  Widget build(BuildContext context) {
    return Glass(
      style: GlassStyle.smoked,
      borderRadius: BorderRadius.circular(AppRadii.md),
      padding: const EdgeInsets.all(_bezel),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.md - _bezel),
        child: ColoredBox(color: AppColors.ink, child: child),
      ),
    );
  }
}

/// YouTube player used across the app.
///
/// youtube_player_flutter 10 builds its controls with `package:material_ui`,
/// while the rest of the app still uses `package:flutter/material.dart`.
/// The two libraries have separate Theme/Material types, so this wrapper gives
/// the player a material_ui Theme (with the brand colours) and a Material
/// ancestor for its buttons.
class AppYoutubePlayer extends StatelessWidget {
  const AppYoutubePlayer({super.key, required this.controller});

  final YoutubePlayerController controller;

  /// Builds a controller for a YouTube URL (or bare video id), or returns null
  /// if the URL is not a recognised YouTube link.
  static YoutubePlayerController? controllerFor(String url) {
    final videoId = YoutubePlayerController.convertUrlToId(url);
    if (videoId == null) return null;
    return YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        mute: false,
        showFullscreenButton: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const white = Color(0xFFFFFFFF);
    return PlayerFrame(
      child: mui.Theme(
        // Dark scheme: the controls sit on video, so they are white with a
        // mint seek bar, the same accent the scanner uses.
        data: mui.ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: AppColors.indigo,
          extensions: [
            YoutubePlayerTheme(
              progressBarActiveColor: AppColors.mintBright,
              progressBarBufferedColor: white.withValues(alpha: 0.38),
              progressBarBackgroundColor: white.withValues(alpha: 0.18),
              controlsColor: white,
              titleStyle: AppText.body(
                size: 14,
                weight: FontWeight.w600,
                color: white,
              ),
              timerStyle: AppText.label(size: 12, color: white),
            ),
          ],
        ),
        child: mui.Material(
          type: mui.MaterialType.transparency,
          child: YoutubePlayer(
            controller: controller,
            backgroundColor: AppColors.ink,
          ),
        ),
      ),
    );
  }
}
