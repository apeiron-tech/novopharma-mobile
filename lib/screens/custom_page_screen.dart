import 'package:novopharma/screens/product_screen.dart';
import 'package:novopharma/widgets/app_network_image.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:novopharma/models/custom_page_model.dart';
import 'package:novopharma/services/custom_page_service.dart';
import 'package:novopharma/design/design.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart'
    show YoutubePlayerController;
import 'package:novopharma/widgets/app_youtube_player.dart';
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
        _youtubeController = AppYoutubePlayer.controllerFor(page.videoUrl!);
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
    _youtubeController?.close();
    _videoPlayerController?.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _youtubeController;
    return _buildScaffold(
      controller != null ? AppYoutubePlayer(controller: controller) : null,
    );
  }

  // How far the title sheet rides up over the hero's bottom edge.
  static const double _sheetOverlap = 48;

  Widget _buildScaffold(Widget? youtubePlayerWidget) {
    // While the page loads (or fails) there is no imagery yet, so its name
    // sits in an ink bar. Once it is ready the gallery becomes the hero and
    // the title moves onto the glass sheet below it.
    final showBar = _isLoading || _errorMessage != null;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: showBar ? _buildHeader(context) : null,
      body: AppBackground(
        child: _isLoading
            ? _buildLoadingWidget()
            : _errorMessage != null
                ? _buildErrorWidget()
                : _buildMainContent(youtubePlayerWidget),
      ),
    );
  }

  // Ink bar shown until the page's own hero is ready
  PreferredSizeWidget _buildHeader(BuildContext context) {
    return InkAppBar(
      title: _page?.title ?? 'Page Personnalisée',
      subtitle: _page?.marqueName != null && _page!.marqueName!.isNotEmpty
          ? _page!.marqueName!
          : null,
      onBack: () => Navigator.of(context).pop(),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CapsuleLoader(),
          const SizedBox(height: 16),
          Text(
            "Chargement de la page...",
            style: AppText.body(size: 14, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return EmptyState(
      icon: Icons.info_outline_rounded,
      tone: Tone.coral,
      title: _errorMessage ?? "Une erreur s'est produite",
      actionLabel: "Réessayer",
      onAction: _fetchPageData,
    );
  }

  /// Keeps the reading column at a comfortable measure on tablets.
  Widget _column(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: child,
      ),
    );
  }

  Widget _buildMainContent(Widget? youtubePlayerWidget) {
    final page = _page!;
    final media = MediaQuery.of(context);
    final hasGallery = page.imageUrls.isNotEmpty;
    final heroHeight = media.padding.top + (hasGallery ? 250.0 : 140.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(bottom: media.padding.bottom + 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Hero: the Image Gallery Carousel (or the aurora when
                  // the page has no images), with the title sheet — Logo,
                  // Marque, Title — overlapping its bottom edge.
                  Stack(
                    children: [
                      if (hasGallery)
                        _buildGallerySection(page, heroHeight)
                      else
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(AppRadii.xl),
                          ),
                          child: SizedBox(
                            height: heroHeight,
                            width: double.infinity,
                            child: const AuroraBackground(),
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          heroHeight - _sheetOverlap,
                          16,
                          0,
                        ),
                        child: _column(_buildHeroCard(page)),
                      ),
                    ],
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    child: _column(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 2. Main Rich Text Description Card
                          _buildDescriptionCard(page),

                          // 3. Video Player Card
                          if (page.videoUrl != null &&
                              page.videoUrl!.isNotEmpty) ...[
                            const SizedBox(height: 26),
                            _buildVideoSection(page, youtubePlayerWidget),
                          ],

                          // 4. PDF Attachment Card
                          if (page.attachmentUrl != null &&
                              page.attachmentUrl!.isNotEmpty) ...[
                            const SizedBox(height: 26),
                            _buildPdfSection(page),
                          ],

                          // 5. Products Section
                          if (page.products.isNotEmpty) ...[
                            const SizedBox(height: 26),
                            _buildProductsSection(page.products),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // An ink mist behind the status bar, so its icons stay readable
          // once the page has scrolled up underneath them.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: media.padding.top + 28,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.ink.withValues(alpha: 0.5),
                      AppColors.ink.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // The way back, floating over the hero on smoked glass.
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Glass(
                  style: GlassStyle.smoked,
                  blur: Glass.frost,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  child: GlassIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Title sheet: Logo, Marque & Title on frosted glass
  Widget _buildHeroCard(CustomPageModel page) {
    final hasLogo = page.logoUrl != null && page.logoUrl!.isNotEmpty;

    // Frosted for real: this pane floats over the picture.
    return SoftCard(
      blur: Glass.frost,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Entrance(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasLogo) ...[
              Container(
                height: 64,
                width: 64,
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.sm + 2),
                  border: Border.all(color: AppColors.line),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.sm + 2),
                  child: CachedNetworkImage(
                    imageUrl: page.logoUrl!,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const SizedBox.expand(
                      child: Shimmer(child: SkeletonBox(radius: 0)),
                    ),
                    errorWidget: (context, url, error) => const Icon(
                      Icons.business_rounded,
                      size: 30,
                      color: AppColors.lineStrong,
                    ),
                  ),
                ),
              ),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (page.marqueName != null &&
                      page.marqueName!.isNotEmpty) ...[
                    // Scales down rather than overflowing on a long name.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: TonePill(
                        label: page.marqueName!,
                        icon: Icons.local_offer_rounded,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    page.title,
                    style: AppText.display(size: 24, height: 1.12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Gallery Section — the page's hero
  Widget _buildGallerySection(CustomPageModel page, double height) {
    final hasTitle =
        page.galleryTitle != null && page.galleryTitle!.trim().isNotEmpty;
    final topInset = MediaQuery.paddingOf(context).top;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(AppRadii.xl),
      ),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CarouselSlider.builder(
              carouselController: _carouselController,
              itemCount: page.imageUrls.length,
              options: CarouselOptions(
                height: height,
                viewportFraction: 1,
                enableInfiniteScroll: page.imageUrls.length > 1,
                onPageChanged: (index, reason) {
                  setState(() {
                    _currentCarouselIndex = index;
                  });
                },
              ),
              itemBuilder: (context, index, realIndex) {
                final imageUrl = page.imageUrls[index];
                return AppNetworkImage(
                  imageUrl: imageUrl,
                  width: double.infinity,
                  height: height,
                  fit: BoxFit.cover,
                  memCacheWidth: 800,
                  memCacheHeight: 550,
                  errorIcon: Icons.broken_image_rounded,
                  errorIconSize: 44,
                );
              },
            ),

            // Arrow Navigation Buttons (Left & Right)
            if (page.imageUrls.length > 1) ...[
              Positioned(
                left: 8,
                child: _AnimatingArrowButton(
                  icon: Icons.chevron_left_rounded,
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
                right: 8,
                child: _AnimatingArrowButton(
                  icon: Icons.chevron_right_rounded,
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
                top: topInset + 16,
                right: 16,
                child: _buildSmokedChip(
                  child: Text(
                    '${_currentCarouselIndex + 1} / ${page.imageUrls.length}',
                    style: AppText.display(size: 13, color: Colors.white),
                  ),
                ),
              ),

            // Caption and page dots, kept clear of the title sheet.
            if (hasTitle || page.imageUrls.length > 1)
              Positioned(
                left: 16,
                right: 16,
                bottom: _sheetOverlap + 12,
                child: IgnorePointer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasTitle)
                        _buildSmokedChip(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.collections_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  page.galleryTitle!.trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.label(
                                    weight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (hasTitle && page.imageUrls.length > 1)
                        const SizedBox(height: 10),
                      if (page.imageUrls.length > 1)
                        Center(
                          child: _buildSmokedChip(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: page.imageUrls.asMap().entries.map((
                                entry,
                              ) {
                                final active =
                                    _currentCarouselIndex == entry.key;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: active ? 18.0 : 6.0,
                                  height: 6.0,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 2.5,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    color: Colors.white.withValues(
                                      alpha: active ? 1.0 : 0.45,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
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

  /// A small ink pill for labels that sit on imagery.
  Widget _buildSmokedChip({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: child,
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
    final hasTitle =
        page.descriptionTitle != null &&
        page.descriptionTitle!.trim().isNotEmpty;
    final headingFamily = AppText.display().fontFamily;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasTitle) ...[
          _buildSectionHeader(
            title: page.descriptionTitle!.trim(),
            icon: Icons.article_rounded,
          ),
          const SizedBox(height: 14),
        ],
        SizedBox(
          width: double.infinity,
          child: SoftCard(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
            child: Html(
              data: _cleanHtml(page.description),
              onLinkTap: (url, _, __) async {
                if (url != null && await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
              // Reading size: 16 on a 1.55 line, headings in the display face.
              style: {
                "body": Style(
                  fontSize: FontSize(16),
                  color: AppColors.text,
                  lineHeight: const LineHeight(1.55),
                  margin: Margins.zero,
                  padding: HtmlPaddings.zero,
                ),
                "p": Style(
                  margin: Margins.only(bottom: 12),
                  lineHeight: const LineHeight(1.55),
                ),
                "span": Style(backgroundColor: Colors.transparent),
                "h1": Style(
                  fontSize: FontSize(24),
                  fontWeight: FontWeight.w700,
                  fontFamily: headingFamily,
                  color: AppColors.text,
                ),
                "h2": Style(
                  fontSize: FontSize(21),
                  fontWeight: FontWeight.w700,
                  fontFamily: headingFamily,
                  color: AppColors.text,
                ),
                "h3": Style(
                  fontSize: FontSize(18),
                  fontWeight: FontWeight.w700,
                  fontFamily: headingFamily,
                  color: AppColors.text,
                ),
                "a": Style(
                  color: AppColors.indigo,
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
    final hasTitle =
        page.videoTitle != null && page.videoTitle!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasTitle) ...[
          _buildSectionHeader(
            title: page.videoTitle!.trim(),
            icon: Icons.ondemand_video_rounded,
          ),
          const SizedBox(height: 14),
        ],
        // Every state sits in the same ink glass frame; the YouTube player
        // brings its own.
        if (!page.isVideoFile)
          youtubePlayerWidget ??
              PlayerFrame(
                child: SizedBox(
                  height: 210,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        "Impossible de charger la vidéo YouTube",
                        textAlign: TextAlign.center,
                        style: AppText.body(
                          size: 14.5,
                          weight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              )
        else
          PlayerFrame(
            child: _isVideoInitialized && _videoPlayerController != null
                ? _buildNativeVideoPlayer(_videoPlayerController!)
                : const SizedBox(
                    height: 210,
                    child: Center(
                      child: CapsuleLoader(
                        left: Colors.white,
                        right: AppColors.mint,
                      ),
                    ),
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
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.ink.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.38),
                        ),
                      ),
                      child: Icon(
                        value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 36,
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
                  padding: const EdgeInsets.only(left: 14, right: 2),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        AppColors.ink.withValues(alpha: 0.88),
                        AppColors.ink.withValues(alpha: 0),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _formatDuration(position),
                        style: AppText.display(
                          size: 12,
                          weight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: VideoProgressIndicator(
                          controller,
                          allowScrubbing: true,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          colors: VideoProgressColors(
                            playedColor: AppColors.mintBright,
                            bufferedColor: Colors.white.withValues(alpha: 0.38),
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDuration(duration),
                        style: AppText.display(
                          size: 12,
                          weight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                      ),
                      IconButton(
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.fullscreen_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasTitle) ...[
          _buildSectionHeader(
            title: page.pdfTitle!.trim(),
            icon: Icons.picture_as_pdf_rounded,
          ),
          const SizedBox(height: 14),
        ],
        SoftCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              if (_isDownloadingPdf) ...[
                SizedBox(
                  height: 200,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CapsuleLoader(),
                      const SizedBox(height: 14),
                      Text(
                        "Chargement du document PDF...",
                        style: AppText.body(
                          size: 14,
                          weight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_localPdfPath != null) ...[
                // The preview is a native view: it answers the tap without
                // the usual press-in, which would distort it.
                Pressable(
                  pressedScale: 1,
                  onTap: _openFullPdfViewer,
                  child: Container(
                    height: 380,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadii.md - 4),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.md - 4),
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
                                  child: _buildSmokedChip(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.picture_as_pdf_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          "Page ${_pdfCurrentPage + 1} sur $_pdfTotalPages",
                                          style: AppText.display(
                                            size: 12.5,
                                            weight: FontWeight.w600,
                                            color: Colors.white,
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
              ] else if (_pdfError) ...[
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
                  decoration: BoxDecoration(
                    color: AppColors.coralTint,
                    borderRadius: BorderRadius.circular(AppRadii.md - 4),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.coralDeep,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Impossible de prévisualiser le document.",
                          style: AppText.body(size: 13.5),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final Uri uri = Uri.parse(page.attachmentUrl!);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text("Télécharger"),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({required String title, required IconData icon}) {
    return Row(
      children: [
        TintIcon(icon: icon, size: 36),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: AppText.display(size: 20))),
      ],
    );
  }

  // Products Section Component
  Widget _buildProductsSection(List<CustomPageProductItem> products) {
    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header with count badge
          Row(
            children: [
              const TintIcon(icon: Icons.inventory_2_rounded, size: 36),
              const SizedBox(width: 12),
              Expanded(
                // Scales down a touch on narrow phones instead of wrapping.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Produits associés",
                    style: AppText.display(size: 19),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TonePill(label: "${products.length} produits"),
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

              // Arrow Navigation Buttons (Left & Right) like the image carousel
              if (products.length > 1) ...[
                Positioned(
                  left: -8,
                  child: _AnimatingArrowButton(
                    icon: Icons.chevron_left_rounded,
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
                  right: -8,
                  child: _AnimatingArrowButton(
                    icon: Icons.chevron_right_rounded,
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
    return Padding(
      padding: const EdgeInsets.only(right: 10, bottom: 4),
      child: SoftCard(
        radius: AppRadii.md,
        shadow: false,
        padding: const EdgeInsets.all(10),
        semanticLabel: product.name,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductScreen(id: product.id),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Container(
              height: 105,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.sm),
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
                product.marque,
                style: AppText.label(
                  size: 11,
                  weight: FontWeight.w700,
                  color: AppColors.indigo,
                  letterSpacing: 0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 2),

            // Product Name
            Expanded(
              child: Text(
                product.name,
                style: AppText.body(
                  size: 13,
                  weight: FontWeight.w700,
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
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "${product.price.toStringAsFixed(2)} DT",
                        style: AppText.display(
                          size: 14,
                          color: AppColors.indigoDeep,
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                if (product.points > 0)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.amberTint,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      "+${product.points % 1 == 0 ? product.points.toInt() : product.points} pts",
                      style: AppText.display(
                        size: 11,
                        color: AppColors.amberDeep,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A round glass button that steps a carousel. It rests still: the old
/// endless nudge is gone, a press is feedback enough.
class _AnimatingArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isLeft;

  const _AnimatingArrowButton({
    required this.icon,
    required this.onPressed,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    // 36pt disc in a 44pt touch target.
    return Pressable(
      onTap: onPressed,
      pressedScale: 0.9,
      semanticLabel: isLeft ? l10n.previousPageTooltip : l10n.nextPageTooltip,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Glass(
          style: GlassStyle.smoked,
          width: 36,
          height: 36,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
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
    final l10n = MaterialLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: InkAppBar(
        title: widget.title,
        subtitle: _totalPages > 0
            ? 'Page ${_currentPage + 1} / $_totalPages'
            : null,
        actions: [
          if (_totalPages > 1) ...[
            GlassIconButton(
              icon: Icons.keyboard_arrow_up_rounded,
              tooltip: l10n.previousPageTooltip,
              onTap: () {
                if (_currentPage > 0) {
                  _pdfViewController?.setPage(_currentPage - 1);
                }
              },
            ),
            GlassIconButton(
              icon: Icons.keyboard_arrow_down_rounded,
              tooltip: l10n.nextPageTooltip,
              onTap: () {
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
