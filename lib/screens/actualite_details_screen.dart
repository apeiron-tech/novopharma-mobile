import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:photo_view/photo_view.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart'
    show YoutubePlayerController;
import '../widgets/app_youtube_player.dart';
import '../models/blog_post.dart';
import '../design/design.dart';
import '../widgets/video_player_dialog.dart';

class ActualiteDetailsScreen extends StatefulWidget {
  final BlogPost actualite;

  const ActualiteDetailsScreen({super.key, required this.actualite});

  @override
  State<ActualiteDetailsScreen> createState() => _ActualiteDetailsScreenState();
}

class _ActualiteDetailsScreenState extends State<ActualiteDetailsScreen> {
  YoutubePlayerController? _youtubeController;

  @override
  void initState() {
    super.initState();
    _initYoutubeVideo();
  }

  void _initYoutubeVideo() {
    final youtubeUrl = widget.actualite.youtubeVideoUrl;
    if (youtubeUrl != null && youtubeUrl.isNotEmpty) {
      _youtubeController = AppYoutubePlayer.controllerFor(youtubeUrl);
    }
  }

  @override
  void dispose() {
    _youtubeController?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _youtubeController;
    return _buildScaffold(
      context,
      controller != null ? AppYoutubePlayer(controller: controller) : null,
    );
  }

  // How far the title sheet rides up over the hero's bottom edge.
  static const double _sheetOverlap = 48;

  /// A neutral pill for metadata that should not carry a feature colour.
  static const Tone _quietTone = Tone(
    AppColors.textFaint,
    AppColors.textMuted,
    AppColors.line,
  );

  Widget _buildScaffold(BuildContext context, Widget? youtubePlayerWidget) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: AppBackground(
          child: Stack(
            children: [
              Positioned.fill(
                child: _buildContent(context, youtubePlayerWidget),
              ),
              // An ink mist behind the status bar, so its icons stay
              // readable once the article has scrolled up underneath them.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: topInset + 28,
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
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildHeader(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The way back, floating over the cover on smoked glass.
  Widget _buildHeader(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: _GlassCrumb(
            label: 'Détails Actualité',
            onBack: () => Navigator.of(context).pop(),
          ),
        ),
      ),
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

  /// The cover as the page's hero — or the aurora when the story has none.
  Widget _buildCover(double height) {
    final coverImageUrl = widget.actualite.coverImageUrl;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(AppRadii.xl),
      ),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: coverImageUrl != null && coverImageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: coverImageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => const SizedBox.expand(
                  child: Shimmer(child: SkeletonBox(radius: 0)),
                ),
                errorWidget: (context, url, error) => const SizedBox.expand(
                  child: AuroraBackground(animate: false),
                ),
              )
            : const AuroraBackground(),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        TintIcon(icon: icon, size: 36),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: AppText.display(size: 20))),
      ],
    );
  }

  Widget _buildContent(BuildContext context, Widget? youtubePlayerWidget) {
    final media = MediaQuery.of(context);
    final hasCover =
        widget.actualite.coverImageUrl != null &&
        widget.actualite.coverImageUrl!.isNotEmpty;
    final heroHeight = media.padding.top + (hasCover ? 250.0 : 140.0);
    final excerpt = widget.actualite.excerpt;
    final hasExcerpt = excerpt != null && excerpt.isNotEmpty;
    final hasBody = widget.actualite.content.isNotEmpty;

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: media.padding.bottom + 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cover Image, with the title sheet overlapping its bottom edge.
          Stack(
            children: [
              _buildCover(heroHeight),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  heroHeight - _sheetOverlap,
                  16,
                  0,
                ),
                child: _column(
                  // Frosted for real: this pane floats over the picture.
                  SoftCard(
                    blur: Glass.frost,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    child: Entrance(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category and date
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              TonePill(
                                label:
                                    widget.actualite.actualiteCategory ??
                                    'Actualité',
                              ),
                              TonePill(
                                label: _formatDate(widget.actualite.createdAt),
                                tone: _quietTone,
                                icon: Icons.schedule_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Title
                          Text(
                            widget.actualite.title,
                            style: AppText.display(size: 26, height: 1.12),
                          ),

                          const SizedBox(height: 12),

                          // Meta Information
                          Row(
                            children: [
                              const Icon(
                                Icons.person_rounded,
                                size: 16,
                                color: AppColors.textFaint,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  widget.actualite.author ?? 'Admin',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.label(letterSpacing: 0),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _column(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The article: lead paragraph, then the text, at a
                  // reading size.
                  if (hasExcerpt || hasBody)
                    SoftCard(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Excerpt
                          if (hasExcerpt)
                            Container(
                              padding: const EdgeInsets.only(left: 14),
                              decoration: const BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: AppColors.mint,
                                    width: 3,
                                  ),
                                ),
                              ),
                              child: Text(
                                excerpt,
                                style: AppText.body(
                                  size: 17,
                                  weight: FontWeight.w500,
                                  height: 1.5,
                                ),
                              ),
                            ),

                          if (hasExcerpt && hasBody)
                            const SizedBox(height: 20),

                          // Content
                          if (hasBody)
                            Text(
                              widget.actualite.content,
                              style: AppText.body(size: 16, height: 1.55),
                            ),
                        ],
                      ),
                    ),

                  // Video Section
                  if (_youtubeController != null &&
                      youtubePlayerWidget != null) ...[
                    const SizedBox(height: 26),
                    _buildYoutubePlayerSection(youtubePlayerWidget),
                  ] else if (widget.actualite.hasVideo ||
                      (widget.actualite.youtubeVideoUrl != null &&
                          widget.actualite.youtubeVideoUrl!.isNotEmpty) ||
                      (widget.actualite.videoUrl != null &&
                          widget.actualite.videoUrl!.isNotEmpty)) ...[
                    const SizedBox(height: 26),
                    _buildOpenVideoButtonSection(),
                  ],

                  // Media Section (Only PDF files)
                  if (widget.actualite.pdfFiles.isNotEmpty) ...[
                    const SizedBox(height: 26),
                    _buildSectionTitle(
                      'Fichiers & Médias',
                      Icons.folder_rounded,
                    ),
                    const SizedBox(height: 14),
                    ...widget.actualite.pdfFiles.map((mediaFile) {
                      return _buildMediaItem(mediaFile);
                    }),
                  ],

                  // Tags
                  if (widget.actualite.tags.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Text('Tags', style: AppText.label(letterSpacing: 0)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.actualite.tags.map((tag) {
                        return TonePill(label: tag, tone: _quietTone);
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaItem(dynamic mediaFile) {
    // Handle different media file formats
    String fileName = '';
    String fileUrl = '';
    String fileType = '';
    int fileSize = 0;
    bool isVideo = false;
    bool isPdf = false;
    bool isImage = false;

    if (mediaFile is Map<String, dynamic>) {
      fileName = mediaFile['name'] ?? 'Fichier sans nom';
      fileUrl = mediaFile['url'] ?? '';
      fileType = mediaFile['type'] ?? '';
      fileSize = mediaFile['size'] ?? 0;
    } else if (mediaFile.runtimeType.toString().contains('MediaFile')) {
      fileName = mediaFile.name ?? 'Fichier sans nom';
      fileUrl = mediaFile.url ?? '';
      fileType = mediaFile.type ?? '';
      fileSize = mediaFile.size ?? 0;
      isVideo = mediaFile.isVideo ?? false;
      isPdf = mediaFile.isPdf ?? false;
      isImage = mediaFile.isImage ?? false;
    }

    // Determine file type if not explicitly set
    if (fileType.isEmpty) {
      final extension = fileName.toLowerCase().split('.').last;
      switch (extension) {
        case 'mp4':
        case 'mov':
        case 'avi':
        case 'mkv':
          isVideo = true;
          fileType = 'video';
          break;
        case 'pdf':
          isPdf = true;
          fileType = 'pdf';
          break;
        case 'jpg':
        case 'jpeg':
        case 'png':
        case 'gif':
          isImage = true;
          fileType = 'image';
          break;
        default:
          fileType = 'document';
      }
    } else {
      isVideo = fileType.toLowerCase().contains('video');
      isPdf = fileType.toLowerCase().contains('pdf');
      isImage = fileType.toLowerCase().contains('image');
    }

    IconData iconData;
    Tone tone;

    if (isVideo) {
      iconData = Icons.play_circle_filled_rounded;
      tone = Tone.coral;
    } else if (isPdf) {
      iconData = Icons.picture_as_pdf_rounded;
      tone = Tone.coral;
    } else if (isImage) {
      iconData = Icons.image_rounded;
      tone = Tone.peach;
    } else {
      iconData = Icons.insert_drive_file_rounded;
      tone = _quietTone;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        radius: AppRadii.md,
        padding: const EdgeInsets.all(12),
        semanticLabel: fileName,
        onTap: () =>
            _handleMediaTap(fileUrl, fileName, isVideo, isPdf, isImage),
        child: Row(
          children: [
            TintIcon(icon: iconData, tone: tone, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: AppText.body(size: 15, weight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(
                        child: TonePill(
                          label: fileType.toUpperCase(),
                          tone: tone,
                        ),
                      ),
                      if (fileSize > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          _formatFileSize(fileSize),
                          style: AppText.display(
                            size: 13,
                            weight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isVideo ? Icons.play_arrow_rounded : Icons.download_rounded,
              color: tone.deep,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  void _handleMediaTap(
    String url,
    String fileName,
    bool isVideo,
    bool isPdf,
    bool isImage,
  ) async {
    if (url.isEmpty) {
      _showSnackBar('URL du fichier non disponible');
      return;
    }

    try {
      if (isVideo) {
        // Play video in custom player
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => VideoPlayerDialog(
            videoUrl: url,
            videoTitle: fileName,
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        );
      } else if (isImage) {
        // Show image in full-screen viewer
        await _showImageViewer(url, fileName);
      } else {
        // For PDFs and other documents, copy URL to clipboard and show message
        await _handleDocumentFile(url, fileName, isPdf);
      }
    } catch (e) {
      _showSnackBar('Erreur lors de l\'ouverture du fichier: $e');
    }
  }

  Future<void> _showImageViewer(String imageUrl, String imageName) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Stack(
          children: [
            PhotoView(
              imageProvider: CachedNetworkImageProvider(imageUrl),
              backgroundDecoration: const BoxDecoration(color: AppColors.ink),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2.0,
              loadingBuilder: (context, event) => const Center(
                child: CapsuleLoader(
                  left: Colors.white,
                  right: AppColors.mint,
                ),
              ),
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(
                  Icons.broken_image_rounded,
                  color: Colors.white,
                  size: 56,
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Glass(
                style: GlassStyle.smoked,
                blur: Glass.frost,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: GlassIconButton(
                  icon: Icons.close_rounded,
                  tooltip: MaterialLocalizations.of(
                    dialogContext,
                  ).closeButtonTooltip,
                  onTap: () => Navigator.of(dialogContext).pop(),
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Glass(
                style: GlassStyle.smoked,
                blur: Glass.frost,
                borderRadius: BorderRadius.circular(AppRadii.md),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Text(
                  imageName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(
                    size: 15,
                    weight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDocumentFile(
    String url,
    String fileName,
    bool isPdf,
  ) async {
    try {
      // Show dialog with options
      await showGlassDialog<void>(
        context: context,
        child: Builder(
          builder: (dialogContext) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  TintIcon(
                    icon: isPdf
                        ? Icons.picture_as_pdf_rounded
                        : Icons.insert_drive_file_rounded,
                    tone: isPdf ? Tone.coral : Tone.indigo,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      isPdf ? 'Document PDF' : 'Document',
                      style: AppText.display(size: 21),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Fichier: $fileName',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(size: 15, weight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Text(
                'Sélectionnez une option pour ouvrir le document:',
                style: AppText.body(size: 14, color: AppColors.textMuted),
              ),
              const SizedBox(height: 22),
              PrimaryButton(
                label: 'Ouvrir',
                icon: Icons.open_in_new_rounded,
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await _openInBrowser(url);
                },
              ),
              const SizedBox(height: 10),
              SecondaryButton(
                label: 'Copier le lien',
                icon: Icons.link_rounded,
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await _copyUrlToClipboard(url);
                },
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Annuler'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      _showSnackBar('Erreur lors de l\'ouverture du document: $e');
    }
  }

  Future<void> _copyUrlToClipboard(String url) async {
    try {
      await Clipboard.setData(ClipboardData(text: url));
      _showSnackBar('Lien copié dans le presse-papiers');
    } catch (e) {
      _showSnackBar('Erreur lors de la copie: $e');
    }
  }

  Future<void> _openInBrowser(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } else {
        await _copyUrlToClipboard(url);
        _showSnackBar(
          'Impossible d\'ouvrir automatiquement. Lien copié dans le presse-papiers.',
        );
      }
    } catch (e) {
      await _copyUrlToClipboard(url);
      _showSnackBar('Erreur d\'ouverture. Lien copié dans le presse-papiers.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  String _formatDate(DateTime date) {
    final months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _buildYoutubePlayerSection(Widget youtubePlayerWidget) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('Vidéo associée', Icons.ondemand_video_rounded),
        const SizedBox(height: 14),
        // The player brings its own ink glass frame.
        youtubePlayerWidget,
      ],
    );
  }

  Widget _buildOpenVideoButtonSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('Vidéo associée', Icons.ondemand_video_rounded),
        const SizedBox(height: 14),
        PrimaryButton(
          label: "Ouvrir la vidéo",
          icon: Icons.play_circle_filled_rounded,
          onPressed: _openVideo,
        ),
      ],
    );
  }

  void _openVideo() async {
    final videoUrl =
        widget.actualite.videoUrl ?? widget.actualite.youtubeVideoUrl;
    if (videoUrl == null || videoUrl.isEmpty) {
      _showSnackBar('URL de la vidéo non disponible');
      return;
    }

    final isDirectVideo = videoUrl.toLowerCase().endsWith('.mp4') ||
        videoUrl.toLowerCase().endsWith('.mov') ||
        videoUrl.toLowerCase().endsWith('.mkv') ||
        videoUrl.toLowerCase().endsWith('.webm');

    if (isDirectVideo) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => VideoPlayerDialog(
          videoUrl: videoUrl,
          videoTitle: widget.actualite.title,
          onClose: () => Navigator.of(dialogContext).pop(),
        ),
      );
    } else {
      try {
        final Uri url = Uri.parse(videoUrl);
        final launched = await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );

        if (!launched) {
          await launchUrl(url, mode: LaunchMode.inAppBrowserView);
        }
      } catch (e) {
        _showSnackBar('Erreur lors de l\'ouverture de la vidéo');
      }
    }
  }
}

/// Back button and screen name in one smoked-glass pill. It stays put while
/// the article scrolls, so it is frosted and dark enough to read over the
/// cover and over the page alike.
class _GlassCrumb extends StatelessWidget {
  final String label;
  final VoidCallback onBack;

  const _GlassCrumb({required this.label, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Glass(
      style: GlassStyle.smoked,
      blur: Glass.frost,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      padding: const EdgeInsets.fromLTRB(4, 4, 18, 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onTap: onBack,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label(
                size: 14,
                weight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
