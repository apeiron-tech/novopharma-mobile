import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../design/design.dart';

class VideoPlayerDialog extends StatefulWidget {
  final String videoUrl;
  final String videoTitle;
  final VoidCallback onClose;

  const VideoPlayerDialog({
    super.key,
    required this.videoUrl,
    required this.videoTitle,
    required this.onClose,
  });

  @override
  State<VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  void _initializeVideoPlayer() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      await _controller.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });

        // Auto play the video
        _controller.play();

        // Hide controls after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _showControls = false;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage =
              'Erreur lors du chargement de la vidéo: ${e.toString()}';
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            // A still ink backdrop: the glow gives the frosted chrome
            // something to catch without competing with the picture.
            const Positioned.fill(
              child: AuroraBackground(animate: false, pattern: false),
            ),

            // Video Player
            Center(
              child: _hasError
                  ? _buildErrorWidget()
                  : _isInitialized
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        child: GestureDetector(
                          onTap: _toggleControls,
                          child: AspectRatio(
                            aspectRatio: _controller.value.aspectRatio,
                            child: VideoPlayer(_controller),
                          ),
                        ),
                      ),
                    )
                  : _buildLoadingWidget(),
            ),

            // Controls Overlay
            if (_showControls) Positioned.fill(child: _buildControlsOverlay()),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CapsuleLoader(left: Colors.white, right: AppColors.mint),
        const SizedBox(height: 20),
        Text(
          'Chargement de la vidéo...',
          style: AppText.body(
            size: 16,
            weight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    // Scrolls rather than overflowing when the phone is held in landscape.
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 88),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.coral.withValues(alpha: 0.18),
              border: Border.all(color: AppColors.coral.withValues(alpha: 0.4)),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _errorMessage,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(
                size: 16,
                weight: FontWeight.w500,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 28),
          PrimaryButton.mint(
            label: 'Réessayer',
            icon: Icons.refresh_rounded,
            expand: false,
            height: 50,
            onPressed: () {
              setState(() {
                _hasError = false;
                _isInitialized = false;
              });
              _initializeVideoPlayer();
            },
          ),
        ],
      ),
    );
  }

  /// Frosted ink chrome floating over the picture: the title and the way
  /// out at the top, transport at the bottom. The middle stays clear so a
  /// tap still reaches the video.
  Widget _buildControlsOverlay() {
    return Column(
      children: [
        // Top bar with title and close button
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Glass(
              style: GlassStyle.smoked,
              blur: Glass.frost,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              padding: const EdgeInsets.fromLTRB(20, 6, 6, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.videoTitle,
                      style: AppText.display(size: 17, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GlassIconButton(
                    icon: Icons.close_rounded,
                    tooltip:
                        MaterialLocalizations.of(context).closeButtonTooltip,
                    onTap: widget.onClose,
                  ),
                ],
              ),
            ),
          ),
        ),

        const Spacer(),

        // Bottom controls
        if (_isInitialized && !_hasError)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Glass(
                style: GlassStyle.smoked,
                blur: Glass.frost,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                padding: const EdgeInsets.fromLTRB(12, 12, 18, 12),
                child: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: _controller,
                  builder: (context, value, _) {
                    final timeStyle = AppText.display(
                      size: 13,
                      weight: FontWeight.w600,
                      color: Colors.white,
                    );
                    return Row(
                      children: [
                        // Play/Pause button
                        Pressable(
                          onTap: _togglePlayPause,
                          pressedScale: 0.9,
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: AppColors.ink,
                              size: 34,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Progress bar
                              VideoProgressIndicator(
                                _controller,
                                allowScrubbing: true,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                colors: VideoProgressColors(
                                  playedColor: AppColors.mintBright,
                                  bufferedColor:
                                      Colors.white.withValues(alpha: 0.38),
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.18),
                                ),
                              ),

                              // Duration text
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(value.position),
                                    style: timeStyle,
                                  ),
                                  Text(
                                    _formatDuration(value.duration),
                                    style: timeStyle.copyWith(
                                      color:
                                          Colors.white.withValues(alpha: 0.78),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
