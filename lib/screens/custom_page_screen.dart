import 'package:novopharma/screens/product_screen.dart';
import 'package:novopharma/widgets/app_network_image.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:novopharma/models/custom_page_model.dart';
import 'package:novopharma/services/custom_page_service.dart';
import 'package:novopharma/theme.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:novopharma/widgets/video_player_dialog.dart';

class CustomPageScreen extends StatefulWidget {
  final String customPageId;

  const CustomPageScreen({super.key, required this.customPageId});

  @override
  State<CustomPageScreen> createState() => _CustomPageScreenState();
}

class _CustomPageScreenState extends State<CustomPageScreen> {
  final CustomPageService _service = CustomPageService();
  CustomPageModel? _page;
  bool _isLoading = true;
  String? _errorMessage;

  // Media controllers
  YoutubePlayerController? _youtubeController;
  VideoPlayerController? _videoPlayerController;
  bool _isVideoInitialized = false;

  // Product search
  final TextEditingController _productSearchController = TextEditingController();
  String _productSearchQuery = '';

  // PDF state
  String? _localPdfPath;
  bool _isDownloadingPdf = false;
  bool _pdfError = false;
  int _pdfTotalPages = 0;
  int _pdfCurrentPage = 0;

  int _currentCarouselIndex = 0;
  final CarouselSliderController _carouselController = CarouselSliderController();

  int _currentProductIndex = 0;
  final CarouselSliderController _productCarouselController = CarouselSliderController();

  @override
  void initState() {
    super.initState();
    _fetchPageData();
  }

  Future<void> _fetchPageData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final page = await _service.getCustomPage(widget.customPageId);
      if (mounted) {
        if (page == null) {
          setState(() {
            _isLoading = false;
            _errorMessage = "Page introuvable ou supprimée.";
          });
          return;
        }

        setState(() {
          _page = page;
          _isLoading = false;
        });

        _initMedia(page);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Erreur lors du chargement de la page.";
        });
      }
    }
  }

  void _initMedia(CustomPageModel page) {
    if (page.videoUrl != null && page.videoUrl!.isNotEmpty) {
      if (!page.isVideoFile) {
        final videoId = YoutubePlayer.convertUrlToId(page.videoUrl!);
        if (videoId != null) {
          _youtubeController = YoutubePlayerController(
            initialVideoId: videoId,
            flags: const YoutubePlayerFlags(
              autoPlay: false,
              mute: false,
            ),
          );
        }
      } else {
        _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(page.videoUrl!),
        );
        _videoPlayerController!.initialize().then((_) async {
          if (_videoPlayerController!.value.duration == Duration.zero) {
            await _videoPlayerController!.seekTo(const Duration(milliseconds: 100));
            await _videoPlayerController!.seekTo(Duration.zero);
          }
          if (mounted) {
            setState(() {
              _isVideoInitialized = true;
            });
          }
        });
        _videoPlayerController!.addListener(() {
          if (mounted) {
            setState(() {});
          }
        });
      }
    }

    if (page.attachmentUrl != null && page.attachmentUrl!.isNotEmpty) {
      _downloadPdf(page.attachmentUrl!);
    }
  }

  void _openVideoDialog() {
    if (_page?.videoUrl == null) return;
    _videoPlayerController?.pause();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerDialog(
          videoUrl: _page!.videoUrl!,
          videoTitle: _page?.title ?? "Vidéo",
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Future<void> _downloadPdf(String url) async {
    setState(() {
      _isDownloadingPdf = true;
      _pdfError = false;
    });

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/custom_page_pdf_${widget.customPageId}.pdf');
        await file.writeAsBytes(bytes, flush: true);

        if (mounted) {
          setState(() {
            _localPdfPath = file.path;
            _isDownloadingPdf = false;
          });
        }
      } else {
        throw Exception("Failed to load PDF");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloadingPdf = false;
          _pdfError = true;
        });
      }
    }
  }

  void _openFullPdfViewer() {
    if (_localPdfPath == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullPdfScreen(
          filePath: _localPdfPath!,
          title: _page?.title ?? "Document PDF",
        ),
      ),
    );
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    _videoPlayerController?.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_youtubeController != null) {
      return YoutubePlayerBuilder(
        player: YoutubePlayer(
          controller: _youtubeController!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: LightModeColors.novoPharmaBlue,
          progressColors: const ProgressBarColors(
            playedColor: LightModeColors.novoPharmaBlue,
            handleColor: LightModeColors.novoPharmaBlue,
          ),
        ),
        builder: (context, player) {
          return _buildScaffold(player);
        },
      );
    }

    return _buildScaffold(null);
  }

  Widget _buildScaffold(Widget? youtubePlayerWidget) {
    return Scaffold(
      backgroundColor: LightModeColors.lightSurfaceVariant,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _isLoading
                  ? _buildLoadingWidget()
                  : _errorMessage != null
                      ? _buildErrorWidget()
                      : _buildMainContent(youtubePlayerWidget),
            ),
          ],
        ),
      ),
    );
  }

  // Header Gradient Bar
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            LightModeColors.novoPharmaBlue,
            LightModeColors.novoPharmaBlue.withValues(alpha: 0.85),
            LightModeColors.lightSecondary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: LightModeColors.novoPharmaBlue.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _page?.title ?? 'Page Personnalisée',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_page?.marqueName != null && _page!.marqueName!.isNotEmpty)
                  Text(
                    _page!.marqueName!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: LightModeColors.lightPrimary),
          SizedBox(height: 16),
          Text(
            "Chargement de la page...",
            style: TextStyle(
              color: LightModeColors.dashboardTextSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.info_outline_rounded, size: 50, color: Colors.red.shade400),
            ),
            const SizedBox(height: 20),
            Text(
              _errorMessage ?? "Une erreur s'est produite",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: LightModeColors.dashboardTextPrimary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchPageData,
              style: ElevatedButton.styleFrom(
                backgroundColor: LightModeColors.lightPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text("Réessayer", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(Widget? youtubePlayerWidget) {
    final page = _page!;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Hero Card: Logo, Marque, Title & Chips
          _buildHeroCard(page),

          const SizedBox(height: 18),

          // 2. Image Gallery Carousel
          if (page.imageUrls.isNotEmpty) ...[
            _buildGallerySection(page),
            const SizedBox(height: 20),
          ],

          // 3. Main Rich Text Description Card
          _buildDescriptionCard(page),

          const SizedBox(height: 20),

          // 4. Video Player Card
          if (page.videoUrl != null && page.videoUrl!.isNotEmpty) ...[
            _buildVideoSection(page, youtubePlayerWidget),
            const SizedBox(height: 20),
          ],

          // 5. PDF Attachment Card
          if (page.attachmentUrl != null && page.attachmentUrl!.isNotEmpty) ...[
            _buildPdfSection(page),
            const SizedBox(height: 20),
          ],

          // 6. Products Section
          if (page.products.isNotEmpty) ...[
            _buildProductsSection(page.products),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  // Hero Header Card Component
  Widget _buildHeroCard(CustomPageModel page) {
    final hasLogo = page.logoUrl != null && page.logoUrl!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasLogo) ...[
                Container(
                  height: 64,
                  width: 64,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: page.logoUrl!,
                      fit: BoxFit.contain,
                      placeholder: (context, url) =>
                          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.business, size: 30, color: Colors.grey),
                    ),
                  ),
                ),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (page.marqueName != null && page.marqueName!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: LightModeColors.novoPharmaBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_offer, size: 12, color: LightModeColors.novoPharmaBlue),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                page.marqueName!,
                                style: const TextStyle(
                                  color: LightModeColors.novoPharmaBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      page.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: LightModeColors.dashboardTextPrimary,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Gallery Section
  Widget _buildGallerySection(CustomPageModel page) {
    final hasTitle = page.galleryTitle != null && page.galleryTitle!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasTitle) ...[
          _buildSectionHeader(
            title: page.galleryTitle!.trim(),
            icon: Icons.collections_rounded,
          ),
          const SizedBox(height: 10),
        ],
        Stack(
          alignment: Alignment.center,
          children: [
            CarouselSlider.builder(
              carouselController: _carouselController,
              itemCount: page.imageUrls.length,
              options: CarouselOptions(
                height: 250,
                viewportFraction: 0.95,
                enlargeCenterPage: true,
                enableInfiniteScroll: page.imageUrls.length > 1,
                onPageChanged: (index, reason) {
                  setState(() {
                    _currentCarouselIndex = index;
                  });
                },
              ),
              itemBuilder: (context, index, realIndex) {
                final imageUrl = page.imageUrls[index];
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AppNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 800,
                      memCacheHeight: 550,
                      errorIcon: Icons.broken_image_rounded,
                      errorIconSize: 44,
                    ),
                  ),
                );
              },
            ),

            // Animated Arrow Navigation Buttons (Left & Right)
            if (page.imageUrls.length > 1) ...[
              Positioned(
                left: 12,
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
                right: 12,
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

            // Top Right Indicator Chip (1/N)
            if (page.imageUrls.length > 1)
              Positioned(
                top: 12,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_currentCarouselIndex + 1} / ${page.imageUrls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (page.imageUrls.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: page.imageUrls.asMap().entries.map((entry) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _currentCarouselIndex == entry.key ? 20.0 : 8.0,
                height: 8.0,
                margin: const EdgeInsets.symmetric(horizontal: 3.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: LightModeColors.novoPharmaBlue.withValues(
                    alpha: _currentCarouselIndex == entry.key ? 1.0 : 0.25,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  String _cleanHtml(String html) {
    if (html.isEmpty) return '';
    var cleaned = html
        .replaceAll('&nbsp;', ' ')
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u202F', ' ')
        .replaceAll('\u200B', '');

    // Strip inline background-color (e.g. pasted white background from web content)
    cleaned = cleaned.replaceAll(
      RegExp(r'background-color\s*:\s*[^;"]+;?', caseSensitive: false),
      '',
    );
    return cleaned;
  }

  // Description Card Component
  Widget _buildDescriptionCard(CustomPageModel page) {
    final hasTitle = page.descriptionTitle != null && page.descriptionTitle!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasTitle) ...[
          _buildSectionHeader(
            title: page.descriptionTitle!.trim(),
            icon: Icons.article_rounded,
          ),
          const SizedBox(height: 10),
        ],
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Html(
              data: _cleanHtml(page.description),
              onLinkTap: (url, _, __) async {
                if (url != null && await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                }
              },
              style: {
                "body": Style(
                  fontSize: FontSize(15),
                  color: LightModeColors.dashboardTextSecondary,
                  lineHeight: const LineHeight(1.6),
                  margin: Margins.zero,
                  padding: HtmlPaddings.zero,
                ),
                "p": Style(
                  margin: Margins.only(bottom: 12),
                  lineHeight: const LineHeight(1.6),
                ),
                "span": Style(
                  backgroundColor: Colors.transparent,
                ),
                "h1": Style(
                  fontSize: FontSize(22),
                  fontWeight: FontWeight.bold,
                  color: LightModeColors.dashboardTextPrimary,
                ),
                "h2": Style(
                  fontSize: FontSize(19),
                  fontWeight: FontWeight.bold,
                  color: LightModeColors.dashboardTextPrimary,
                ),
                "h3": Style(
                  fontSize: FontSize(17),
                  fontWeight: FontWeight.bold,
                  color: LightModeColors.dashboardTextPrimary,
                ),
                "a": Style(
                  color: LightModeColors.novoPharmaBlue,
                  textDecoration: TextDecoration.underline,
                ),
              },
            ),
          ),
        ),
      ],
    );
  }

  // Video Section Component
  Widget _buildVideoSection(CustomPageModel page, Widget? youtubePlayerWidget) {
    final hasTitle = page.videoTitle != null && page.videoTitle!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasTitle) ...[
          _buildSectionHeader(
            title: page.videoTitle!.trim(),
            icon: Icons.ondemand_video_rounded,
          ),
          const SizedBox(height: 10),
        ],
        Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: !page.isVideoFile
                ? (youtubePlayerWidget ??
                    Container(
                      height: 210,
                      color: Colors.black,
                      child: const Center(
                        child: Text(
                          "Impossible de charger la vidéo YouTube",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ))
                : (_isVideoInitialized && _videoPlayerController != null
                    ? _buildNativeVideoPlayer(_videoPlayerController!)
                    : Container(
                        height: 210,
                        color: Colors.black,
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      )),
          ),
        ),
      ],
    );
  }

  Widget _buildNativeVideoPlayer(VideoPlayerController controller) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        final position = value.position;
        final duration = value.duration;

        return AspectRatio(
          aspectRatio: value.isInitialized && value.aspectRatio > 0
              ? value.aspectRatio
              : 16 / 9,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(controller),
              // Play / Pause Overlay Center Button
              GestureDetector(
                onTap: () {
                  value.isPlaying ? controller.pause() : controller.play();
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color: Colors.transparent,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  ),
                ),
              ),
              // Bottom Timeline Seekbar & Duration Bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.85),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _formatDuration(position),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: VideoProgressIndicator(
                          controller,
                          allowScrubbing: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          colors: const VideoProgressColors(
                            playedColor: LightModeColors.novoPharmaBlue,
                            bufferedColor: Colors.white30,
                            backgroundColor: Colors.white12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDuration(duration),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        icon: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 20),
                        onPressed: _openVideoDialog,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inMilliseconds <= 0) return "00:00";
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final hours = duration.inHours;
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  // PDF Section Component
  Widget _buildPdfSection(CustomPageModel page) {
    final hasTitle = page.pdfTitle != null && page.pdfTitle!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasTitle) ...[
          _buildSectionHeader(
            title: page.pdfTitle!.trim(),
            icon: Icons.picture_as_pdf_rounded,
          ),
          const SizedBox(height: 10),
        ],
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_isDownloadingPdf) ...[
                  Container(
                    height: 200,
                    alignment: Alignment.center,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: LightModeColors.novoPharmaBlue),
                        SizedBox(height: 14),
                        Text(
                          "Chargement du document PDF...",
                          style: TextStyle(
                            color: LightModeColors.dashboardTextSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_localPdfPath != null) ...[
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _openFullPdfViewer,
                      child: Container(
                        height: 380,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(
                            children: [
                              PDFView(
                                filePath: _localPdfPath,
                                enableSwipe: false,
                                swipeHorizontal: false,
                                autoSpacing: true,
                                pageFling: false,
                                onRender: (pages) {
                                  if (mounted) {
                                    setState(() {
                                      _pdfTotalPages = pages ?? 0;
                                    });
                                  }
                                },
                                onPageChanged: (page, total) {
                                  if (mounted) {
                                    setState(() {
                                      _pdfCurrentPage = page ?? 0;
                                      if (total != null) _pdfTotalPages = total;
                                    });
                                  }
                                },
                              ),
                              Positioned.fill(
                                child: Container(
                                  color: Colors.transparent,
                                ),
                              ),
                              if (_pdfTotalPages > 0)
                                Positioned(
                                  bottom: 12,
                                  left: 0,
                                  right: 0,
                                  child: IgnorePointer(
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.7),
                                          borderRadius: BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.15),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.picture_as_pdf_rounded,
                                              color: Colors.white,
                                              size: 13,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              "Page ${_pdfCurrentPage + 1} sur $_pdfTotalPages",
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                          ],
                                        ),
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
                ] else if (_pdfError) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.red),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "Impossible de prévisualiser le document.",
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final Uri uri = Uri.parse(page.attachmentUrl!);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: const Icon(Icons.download, size: 16),
                          label: const Text("Télécharger"),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({required String title, required IconData icon}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 20, color: LightModeColors.novoPharmaBlue),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: LightModeColors.dashboardTextPrimary,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }

  // Products Section Component
  Widget _buildProductsSection(List<CustomPageProductItem> products) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header with count badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: LightModeColors.novoPharmaBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  size: 20,
                  color: LightModeColors.novoPharmaBlue,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Produits associés",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: LightModeColors.dashboardTextPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: LightModeColors.novoPharmaBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${products.length} produits",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: LightModeColors.novoPharmaBlue,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              CarouselSlider.builder(
                carouselController: _productCarouselController,
                itemCount: products.length,
                options: CarouselOptions(
                  height: 240,
                  viewportFraction: 0.54,
                  padEnds: false,
                  enableInfiniteScroll: products.length > 2,
                  enlargeCenterPage: false,
                  onPageChanged: (index, reason) {
                    setState(() {
                      _currentProductIndex = index;
                    });
                  },
                ),
                itemBuilder: (context, index, realIndex) {
                  final product = products[index];
                  return _buildCarouselProductCard(product);
                },
              ),

              // Animated Arrow Navigation Buttons (Left & Right) like the image carousel
              if (products.length > 1) ...[
                Positioned(
                  left: -6,
                  child: _AnimatingArrowButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    isLeft: true,
                    onPressed: () {
                      _productCarouselController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                ),
                Positioned(
                  right: -6,
                  child: _AnimatingArrowButton(
                    icon: Icons.arrow_forward_ios_rounded,
                    isLeft: false,
                    onPressed: () {
                      _productCarouselController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselProductCard(CustomPageProductItem product) {
    return Container(
      margin: const EdgeInsets.only(right: 10, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductScreen(id: product.id),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image
                Container(
                  height: 105,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: LightModeColors.lightBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AppNetworkImage(
                      imageUrl: product.imageUrl,
                      fit: BoxFit.contain,
                      memCacheWidth: 260,
                      memCacheHeight: 260,
                      errorIcon: Icons.inventory_2_outlined,
                      errorIconSize: 30,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Brand
                if (product.marque.isNotEmpty)
                  Text(
                    product.marque.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: LightModeColors.novoPharmaBlue,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 2),

                // Product Name
                Expanded(
                  child: Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: LightModeColors.dashboardTextPrimary,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 6),

                // Price & Points
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (product.price > 0)
                      Text(
                        "${product.price.toStringAsFixed(2)} DT",
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: LightModeColors.novoPharmaBlue,
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    if (product.points > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: LightModeColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: LightModeColors.success.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          "+${product.points % 1 == 0 ? product.points.toInt() : product.points} pts",
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: LightModeColors.success,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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

    _translationAnimation = Tween<double>(
      begin: 0.0,
      end: widget.isLeft ? -5.0 : 5.0,
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
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: InkWell(
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(16),
              child: Icon(
                widget.icon,
                color: LightModeColors.novoPharmaBlue,
                size: 18,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FullPdfScreen extends StatefulWidget {
  final String filePath;
  final String title;

  const _FullPdfScreen({
    required this.filePath,
    required this.title,
  });

  @override
  State<_FullPdfScreen> createState() => _FullPdfScreenState();
}

class _FullPdfScreenState extends State<_FullPdfScreen> {
  int _totalPages = 0;
  int _currentPage = 0;
  PDFViewController? _pdfViewController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: LightModeColors.novoPharmaBlue,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_totalPages > 0)
              Text(
                'Page ${_currentPage + 1} / $_totalPages',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          if (_totalPages > 1) ...[
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up),
              onPressed: () {
                if (_currentPage > 0) {
                  _pdfViewController?.setPage(_currentPage - 1);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: () {
                if (_currentPage < _totalPages - 1) {
                  _pdfViewController?.setPage(_currentPage + 1);
                }
              },
            ),
          ],
        ],
      ),
      body: PDFView(
        filePath: widget.filePath,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
        onViewCreated: (controller) {
          _pdfViewController = controller;
        },
        onRender: (pages) {
          setState(() {
            _totalPages = pages ?? 0;
          });
        },
        onPageChanged: (page, total) {
          setState(() {
            _currentPage = page ?? 0;
            if (total != null) _totalPages = total;
          });
        },
      ),
    );
  }
}
