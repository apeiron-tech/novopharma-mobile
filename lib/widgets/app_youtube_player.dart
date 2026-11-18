import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' as mui;
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../theme.dart';

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
    return mui.Theme(
      data: mui.ThemeData(
        colorSchemeSeed: LightModeColors.novoPharmaBlue,
        extensions: const [
          YoutubePlayerTheme(
            progressBarActiveColor: LightModeColors.novoPharmaBlue,
          ),
        ],
      ),
      child: mui.Material(
        type: mui.MaterialType.transparency,
        child: YoutubePlayer(controller: controller),
      ),
    );
  }
}
