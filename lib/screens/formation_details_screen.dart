import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../widgets/video_player_dialog.dart';
import 'package:novopharma/models/blog_post.dart';
import 'package:novopharma/controllers/quiz_provider.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/screens/quiz_question_screen.dart';
import 'package:novopharma/screens/quiz_correction_screen.dart';
import 'package:novopharma/models/quiz.dart';
import 'package:share_plus/share_plus.dart';
import 'package:novopharma/services/chottu_link_service.dart';
import 'package:novopharma/design/design.dart';

// Helper class for formation steps
class FormationStep {
  final String title;
  final String description;
  final IconData icon;
  bool isCompleted;
  final VoidCallback onTap;

  FormationStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.isCompleted,
    required this.onTap,
  });
}

class FormationDetailsScreen extends StatefulWidget {
  final BlogPost formation;

  const FormationDetailsScreen({super.key, required this.formation});

  @override
  State<FormationDetailsScreen> createState() => _FormationDetailsScreenState();
}

class _FormationDetailsScreenState extends State<FormationDetailsScreen> {
  int _currentStep = 0;

  // Formation steps with completion tracking
  List<FormationStep> _steps = [];
  List<bool> _stepCompletions = [];

  @override
  void initState() {
    super.initState();
    _initializeSteps();
  }

  void _initializeSteps() {
    _steps = [
      if (widget.formation.hasVideo)
        FormationStep(
          title: 'La vidéo de formation',
          description: 'Regarder la vidéo de formation',
          icon: Icons.play_circle_outline_rounded,
          isCompleted: false,
          onTap: () => _showVideosSection(),
        ),
      FormationStep(
        title: 'Contenu de formation',
        description: 'Lire le contenu détaillé',
        icon: Icons.article_rounded,
        isCompleted: false,
        onTap: () => _showContent(),
      ),
      if (widget.formation.hasQuiz)
        FormationStep(
          title: 'Quiz de validation',
          description: 'Valider vos connaissances',
          icon: Icons.quiz_rounded,
          isCompleted: false,
          onTap: () => _startQuiz(),
        ),
    ];
    _stepCompletions = List.generate(_steps.length, (index) => false);
  }

  // How far the title sheet rides up over the hero's bottom edge.
  static const double _sheetOverlap = 48;

  /// A neutral tone for metadata that should not carry a feature colour.
  static const Tone _quietTone = Tone(
    AppColors.textFaint,
    AppColors.textMuted,
    AppColors.line,
  );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final heroHeight =
        media.padding.top + (widget.formation.coverImage != null ? 250.0 : 140.0);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: AppBackground(
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: media.padding.bottom + 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Formation Header
                      _buildFormationHeader(heroHeight),

                      // Progress Indicator
                      _buildProgressIndicator(),

                      // Formation Steps
                      _buildFormationSteps(),

                      // Attachments Section
                      _buildAttachmentsSection(),
                    ],
                  ),
                ),
              ),

              // An ink mist behind the status bar, so its icons stay
              // readable once the page has scrolled up underneath them.
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

              // Back and share, floating over the cover on smoked glass.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: _GlassCrumb(
                            label: 'Formation',
                            onBack: () => Navigator.of(context).pop(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Glass(
                          style: GlassStyle.smoked,
                          blur: Glass.frost,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          padding: const EdgeInsets.all(4),
                          child: GlassIconButton(
                            icon: Icons.share_rounded,
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).shareButtonLabel,
                            onTap: () => _shareFormation(),
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

  /// The cover as the page's hero — or the aurora when the formation has
  /// none — with the title sheet overlapping its bottom edge.
  Widget _buildFormationHeader(double heroHeight) {
    return Stack(
      children: [
        // Cover Image
        ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(AppRadii.xl),
          ),
          child: SizedBox(
            height: heroHeight,
            width: double.infinity,
            child: widget.formation.coverImage != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: widget.formation.coverImage!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const SizedBox.expand(
                          child: Shimmer(child: SkeletonBox(radius: 0)),
                        ),
                        errorWidget: (context, url, error) =>
                            const SizedBox.expand(
                              child: AuroraBackground(animate: false),
                            ),
                      ),
                      // Play icon for video indication
                      if (widget.formation.hasVideo)
                        const Positioned(
                          right: 20,
                          bottom: _sheetOverlap + 14,
                          child: _PlayBadge(),
                        ),
                    ],
                  )
                : const AuroraBackground(),
          ),
        ),

        Padding(
          padding: EdgeInsets.fromLTRB(16, heroHeight - _sheetOverlap, 16, 0),
          child: _column(
            // Frosted for real: this pane floats over the picture.
            SoftCard(
              blur: Glass.frost,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Entrance(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // What it is and when it runs
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        const TonePill(
                          label: 'Formation',
                          icon: Icons.school_rounded,
                        ),
                        if (widget.formation.startDate != null)
                          TonePill(
                            label: widget.formation.formattedStartDate,
                            tone: Tone.mint,
                            icon: Icons.calendar_today_rounded,
                          ),
                        if (widget.formation.endDate != null)
                          TonePill(
                            label: 'Fin: ${widget.formation.formattedEndDate}',
                            tone: _quietTone,
                            icon: Icons.event_available_rounded,
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Title and metadata
                    Text(
                      widget.formation.title,
                      style: AppText.display(size: 26, height: 1.12),
                    ),

                    const SizedBox(height: 12),

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
                            'Par ${widget.formation.author ?? 'N/A'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.label(letterSpacing: 0),
                          ),
                        ),
                      ],
                    ),

                    // Tags
                    if (widget.formation.tags.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text(
                        'Catégories',
                        style: AppText.label(letterSpacing: 0),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.formation.tags.map((tag) {
                          return TonePill(label: tag, tone: _quietTone);
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    if (_steps.isEmpty) return const SizedBox.shrink();

    final completedSteps = _stepCompletions
        .where((completed) => completed)
        .length;
    final progress = completedSteps / _steps.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: _column(
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Progression',
                      style: AppText.display(size: 18),
                    ),
                  ),
                  TonePill(
                    label: '$completedSteps/${_steps.length} étapes',
                    tone: Tone.mint,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CapsuleProgress(
                value: progress,
                tone: progress < 1.0 ? Tone.indigo : Tone.mint,
              ),
              const SizedBox(height: 10),
              Text(
                progress == 1.0
                    ? 'Formation terminée! 🎉'
                    : '${(progress * 100).toInt()}% complété',
                style: AppText.display(
                  size: 15,
                  weight: FontWeight.w600,
                  color: progress == 1.0
                      ? AppColors.mintDeep
                      : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The formation as a sequence: numbered markers joined by a line, mint
  /// once a step is done, indigo on the step that comes next.
  Widget _buildFormationSteps() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 26, 16, 0),
      child: _column(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const TintIcon(icon: Icons.school_rounded, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Étapes de formation',
                    style: AppText.display(size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SoftCard(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  for (var index = 0; index < _steps.length; index++)
                    _buildStepRow(index),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepRow(int index) {
    final step = _steps[index];
    final isCompleted = _stepCompletions[index];
    final isActive = index == _currentStep;
    final isLast = index == _steps.length - 1;

    return Pressable(
      onTap: step.onTap,
      pressedScale: 0.98,
      child: AnimatedContainer(
        duration: AppMotion.medium,
        curve: AppMotion.emphasized,
        padding: const EdgeInsets.fromLTRB(10, 10, 6, 0),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.indigoTint.withValues(alpha: 0.75)
              : AppColors.indigoTint.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Numbered marker, and the line down to the next one.
              Column(
                children: [
                  _StepMarker(
                    number: index + 1,
                    completed: isCompleted,
                    active: isActive,
                  ),
                  Expanded(
                    child: isLast
                        ? const SizedBox.shrink()
                        : Container(
                            width: 2,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? AppColors.mint
                                  : AppColors.lineStrong,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                  ),
                ],
              ),

              const SizedBox(width: 14),

              // Step Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 1, bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: AppText.display(size: 16.5, height: 1.15),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Icon(
                              step.icon,
                              size: 16,
                              color: isActive
                                  ? AppColors.indigo
                                  : AppColors.textFaint,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              step.description,
                              style: AppText.body(
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (isCompleted) ...[
                        const SizedBox(height: 8),
                        const TonePill(
                          label: 'Terminé',
                          tone: Tone.mint,
                          icon: Icons.check_rounded,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Arrow Icon
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Center(
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 24,
                    color: isActive ? AppColors.indigo : AppColors.textFaint,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentsSection() {
    final attachments = <Map<String, dynamic>>[];

    // Add PDF attachments
    for (final pdfFile in widget.formation.pdfFiles) {
      attachments.add({
        'title': pdfFile.name,
        'type': 'PDF • ${pdfFile.formattedSize}',
        'icon': Icons.picture_as_pdf_rounded,
        'tone': Tone.coral,
        'file': pdfFile,
        'onTap': () => _openPDF(pdfFile),
      });
    }

    // Add image attachments
    for (final imageFile in widget.formation.imageFiles) {
      attachments.add({
        'title': imageFile.name,
        'type': 'Image • ${imageFile.formattedSize}',
        'icon': Icons.image_rounded,
        'tone': Tone.mint,
        'file': imageFile,
        'onTap': () => _openImage(imageFile),
      });
    }

    // Add other file attachments
    for (final otherFile in widget.formation.otherFiles) {
      IconData icon = Icons.attachment_rounded;
      Tone tone = _quietTone;

      if (otherFile.name.toLowerCase().contains('clinical') ||
          otherFile.name.toLowerCase().contains('study') ||
          otherFile.name.toLowerCase().contains('etude')) {
        icon = Icons.science_rounded;
        tone = Tone.indigo;
      }

      attachments.add({
        'title': otherFile.name,
        'type': '${otherFile.type.toUpperCase()} • ${otherFile.formattedSize}',
        'icon': icon,
        'tone': tone,
        'file': otherFile,
        'onTap': () => _openAttachment(otherFile),
      });
    }

    if (attachments.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 26, 16, 0),
      child: _column(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const TintIcon(
                  icon: Icons.attachment_rounded,
                  tone: Tone.peach,
                  size: 36,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pièces jointes', style: AppText.display(size: 20)),
                      const SizedBox(height: 2),
                      Text(
                        '${attachments.length} fichier${attachments.length > 1 ? 's' : ''} disponible${attachments.length > 1 ? 's' : ''}',
                        style: AppText.body(
                          size: 13.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...attachments.map(
              (attachment) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SoftCard(
                  radius: AppRadii.md,
                  padding: const EdgeInsets.all(12),
                  semanticLabel: attachment['title'] as String,
                  onTap: attachment['onTap'] as VoidCallback,
                  child: Row(
                    children: [
                      TintIcon(
                        icon: attachment['icon'] as IconData,
                        tone: attachment['tone'] as Tone,
                        size: 48,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              attachment['title'] as String,
                              style: AppText.body(
                                size: 15,
                                weight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: TonePill(
                                label: attachment['type'] as String,
                                tone: attachment['tone'] as Tone,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.download_rounded,
                        size: 22,
                        color: AppColors.textFaint,
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

  // Action Methods
  void _showVideosSection() async {
    if (!widget.formation.hasVideo) {
      _showSnackBar('Aucune vidéo disponible pour cette formation');
      return;
    }

    // Check if youtubeVideoUrl is available first
    if (widget.formation.youtubeVideoUrl != null &&
        widget.formation.youtubeVideoUrl!.isNotEmpty) {
      try {
        final Uri url = Uri.parse(widget.formation.youtubeVideoUrl!);
        final launched = await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );

        if (!launched) {
          // Try with inAppBrowserView as fallback
          await launchUrl(url, mode: LaunchMode.inAppBrowserView);
        }
        _completeStep(0); // Mark video step as completed
        return;
      } catch (e) {
        print('Error launching video: $e');
        _showSnackBar('Erreur lors de l\'ouverture de la vidéo');
        return;
      }
    }

    // Check if there are video files in media array
    final videoFiles = widget.formation.videoFiles;

    // If there's only one video file and it's a YouTube link, launch it directly
    if (videoFiles.length == 1) {
      final videoFile = videoFiles.first;
      if (videoFile.url.contains('youtube.com') ||
          videoFile.url.contains('youtu.be') ||
          videoFile.url.contains('vimeo.com')) {
        try {
          final Uri url = Uri.parse(videoFile.url);
          final launched = await launchUrl(
            url,
            mode: LaunchMode.externalApplication,
          );

          if (!launched) {
            await launchUrl(url, mode: LaunchMode.inAppBrowserView);
          }
          _completeStep(0); // Mark video step as completed
          return;
        } catch (e) {
          print('Error launching video: $e');
          _showSnackBar('Erreur lors de l\'ouverture de la vidéo');
          return;
        }
      }
    }

    // If multiple videos or non-YouTube videos, show the modal

    showDialog(
      context: context,
      barrierColor: AppColors.ink.withValues(alpha: 0.55),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Glass(
          blur: Glass.frost,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 14, 8),
                child: Row(
                  children: [
                    const TintIcon(
                      icon: Icons.video_library_rounded,
                      size: 40,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Vidéos de formation',
                        style: AppText.display(size: 20),
                      ),
                    ),
                    _QuietIconButton(
                      icon: Icons.close_rounded,
                      tooltip:
                          MaterialLocalizations.of(context).closeButtonTooltip,
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Content area
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  itemCount: videoFiles.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: SoftCard(
                        padding: EdgeInsets.zero,
                        shadow: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: 150,
                              child: widget.formation.coverImage != null
                                  ? CachedNetworkImage(
                                      imageUrl: widget.formation.coverImage!,
                                      width: double.infinity,
                                      height: 150,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                          const SizedBox.expand(
                                            child: Shimmer(
                                              child: SkeletonBox(radius: 0),
                                            ),
                                          ),
                                    )
                                  : const ColoredBox(
                                      color: AppColors.indigoTint,
                                      child: Center(
                                        child: Icon(
                                          Icons.video_library_rounded,
                                          size: 44,
                                          color: AppColors.lineStrong,
                                        ),
                                      ),
                                    ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                14,
                                16,
                                16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    videoFiles[index].name,
                                    style: AppText.display(
                                      size: 16.5,
                                      height: 1.15,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    videoFiles[index].formattedSize,
                                    style: AppText.display(
                                      size: 13,
                                      weight: FontWeight.w600,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  PrimaryButton(
                                    label: 'Regarder la vidéo',
                                    icon: Icons.play_arrow_rounded,
                                    height: 50,
                                    onPressed: () =>
                                        _playVideo(videoFiles[index]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ), // ListView.builder
              ), // Expanded
            ],
          ),
        ),
      ),
    ).then((_) {
      _completeStep(0); // Mark video step as completed
    });
  }

  void _playVideo(MediaFile videoFile) async {
    Navigator.pop(context);

    try {
      // Check if it's a YouTube or Vimeo URL (open externally)
      if (videoFile.url.contains('youtube.com') ||
          videoFile.url.contains('youtu.be') ||
          videoFile.url.contains('vimeo.com')) {
        final Uri videoUri = Uri.parse(videoFile.url);
        final launched = await launchUrl(
          videoUri,
          mode: LaunchMode.externalApplication,
        );

        if (!launched) {
          // Try with inAppBrowserView as fallback
          await launchUrl(videoUri, mode: LaunchMode.inAppBrowserView);
        }
        return;
      }

      // For direct video files, use in-app video player
      _showVideoPlayer(videoFile);
    } catch (e) {
      _showSnackBar('Erreur lors de la lecture de la vidéo');
    }
  }

  void _showVideoPlayer(MediaFile videoFile) {
    showDialog(
      context: context,
      barrierColor: AppColors.ink.withValues(alpha: 0.9),
      builder: (context) => Dialog.fullscreen(
        backgroundColor: AppColors.ink,
        child: VideoPlayerDialog(
          videoUrl: videoFile.url,
          videoTitle: videoFile.name,
          onClose: () {
            Navigator.pop(context);
            _completeStep(0); // Mark video step as completed
          },
        ),
      ),
    );
  }

  void _showContent() {
    showGlassDialog<void>(
      context: context,
      child: Builder(
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.formation.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppText.display(size: 21),
            ),
            const SizedBox(height: 14),
            // The lesson itself, at a reading size. It takes what height the
            // screen can spare and scrolls beyond that.
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.6,
                ),
                child: SingleChildScrollView(
                  child: Text(
                    widget.formation.content,
                    style: AppText.body(size: 16, height: 1.55),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'Fermer',
              onPressed: () {
                Navigator.of(context).pop();
                _completeStep(
                  _steps.indexWhere((s) => s.title == 'Contenu de formation'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _startQuiz() async {
    if (!widget.formation.hasQuiz) {
      _showSnackBar('Aucun quiz disponible pour cette formation');
      return;
    }

    if (widget.formation.linkedQuizId == null ||
        widget.formation.linkedQuizId!.isEmpty) {
      _showSnackBar('Aucun quiz associé à cette formation');
      return;
    }

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CapsuleLoader(left: Colors.white, right: AppColors.mint),
        ),
      );

      final quizProvider = Provider.of<QuizProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.firebaseUser?.uid;

      if (userId == null) {
        Navigator.pop(context); // Close loading dialog
        _showSnackBar('Utilisateur non connecté');
        return;
      }

      await quizProvider.fetchAllQuizzes(userId);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      final quiz = quizProvider.quizzes.firstWhere(
        (q) => q.id == widget.formation.linkedQuizId,
        orElse: () => throw Exception('Quiz non trouvé'),
      );

      final attempts = quizProvider.userAttempts[quiz.id] ?? 0;
      if (!quiz.isAvailable) {
        if (attempts > 0) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  QuizCorrectionScreen(quizId: quiz.id, quiz: quiz),
            ),
          );
        } else {
          _showSnackBar('Ce quiz est actuellement clôturé.');
        }
        return;
      }
      if (attempts >= quiz.attemptLimit) {
        _showSnackBar(
          'Vous avez atteint la limite de tentatives pour ce quiz (${attempts}/${quiz.attemptLimit})',
        );
        return;
      }

      showGlassDialog<void>(
        context: context,
        child: Builder(
          builder: (BuildContext context) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const BlisterIcon(
                      icon: Icons.quiz_rounded,
                      tone: Tone.amber,
                      size: 48,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Quiz de validation',
                        style: AppText.display(size: 21),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Formation: ${widget.formation.title}',
                  style: AppText.body(size: 15, weight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Condition de réussite: minimum ${quiz.effectiveMinCorrectAnswers} bonnes réponses sur ${quiz.questions.length}',
                  style: AppText.body(size: 14.5, color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                Text(
                  'Êtes-vous prêt(e) à commencer le quiz de validation ?',
                  style: AppText.body(size: 15),
                ),
                const SizedBox(height: 22),
                PrimaryButton(
                  label: 'Commencer',
                  onPressed: () {
                    Navigator.of(context).pop();
                    _navigateToQuiz(quiz);
                  },
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      _showSnackBar('Erreur lors du chargement du quiz: $e');
    }
  }

  void _navigateToQuiz(Quiz quiz) async {
    final quizProvider = Provider.of<QuizProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.firebaseUser?.uid;

    if (userId == null) return;

    try {
      // Navigate to quiz question screen
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => QuizQuestionScreen(quiz: quiz)),
      );

      // If quiz was completed successfully, mark step as complete
      if (result == true) {
        _completeStep(
          _steps.indexWhere((s) => s.title == 'Quiz de validation'),
        );
        _showSnackBar('Quiz terminé avec succès!');
      }
    } catch (e) {
      _showSnackBar('Erreur lors du quiz: $e');
    }
  }

  void _openPDF(MediaFile pdfFile) async {
    await _launchFile(pdfFile, 'PDF');
  }

  void _openImage(MediaFile imageFile) async {
    await _launchFile(imageFile, 'image');
  }

  void _openAttachment(MediaFile file) async {
    await _launchFile(file, 'fichier');
  }

  Future<void> _launchFile(MediaFile file, String fileType) async {
    final Uri fileUri = Uri.parse(file.url);
    await _launchUrlWithFallback(fileUri, fileType);
  }

  Future<void> _launchUrlWithFallback(
    Uri uri,
    String contentType, {
    bool isVideo = false,
  }) async {
    try {
      // Special handling for Firebase Storage URLs
      bool isFirebaseStorage =
          uri.host.contains('firebasestorage') ||
          uri.host.contains('googleapis.com');

      // For videos, especially Firebase Storage videos
      if (isVideo) {
        // Firebase Storage videos work better with platform default or browser
        if (isFirebaseStorage) {
          try {
            await launchUrl(
              uri,
              mode: LaunchMode.inAppBrowserView,
              browserConfiguration: const BrowserConfiguration(showTitle: true),
            );
            _showSnackBar('Lecture de la $contentType dans le navigateur');
            return;
          } catch (e) {
            // Fallback silently
          }
        }

        // Try external video player
        try {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            _showSnackBar('Ouverture de la $contentType');
            return;
          }
        } catch (e) {
          // Fallback silently
        }
      }

      // Try external application for any file type
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          _showSnackBar(
            'Ouverture du $contentType dans une application externe',
          );
          return;
        }
      } catch (e) {
        // Fallback silently
      }

      // Fallback 1: Try platform default (let system decide)
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
          _showSnackBar('Ouverture du $contentType');
          return;
        }
      } catch (e) {
        // Fallback silently
      }

      // Fallback 2: In-app browser (for downloads)
      try {
        await launchUrl(
          uri,
          mode: LaunchMode.inAppBrowserView,
          browserConfiguration: const BrowserConfiguration(showTitle: true),
        );
        _showSnackBar('Ouverture du $contentType...');
        return;
      } catch (e) {
        // Fallback silently
      }

      // Fallback 3: External browser
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _showSnackBar('Ouverture dans le navigateur...');
        return;
      } catch (e) {
        // Final fallback failed silently
      }

      // If all else fails
      _showSnackBar(
        'Impossible d\'ouvrir le $contentType. Veuillez vérifier vos applications.',
      );
    } catch (e) {
      _showSnackBar('Erreur lors de l\'ouverture du $contentType');
    }
  }

  void _shareFormation() async {
    _showSnackBar('Génération du lien de partage...');

    try {
      final String? link = await ChottuLinkService().createFormationLink(
        widget.formation.id,
      );

      if (link != null) {
        await SharePlus.instance.share(
          ShareParams(
            text:
                'Consultez cette formation sur MyChallenge : ${widget.formation.title}\n\nLien : $link',
          ),
        );
      } else {
        _showSnackBar('Erreur lors de la génération du lien');
      }
    } catch (e) {
      _showSnackBar('Erreur lors du partage');
    }
  }

  void _completeStep(int stepIndex) {
    if (stepIndex >= 0 && stepIndex < _stepCompletions.length) {
      setState(() {
        _stepCompletions[stepIndex] = true;
        if (stepIndex == _currentStep && _currentStep < _steps.length - 1) {
          _currentStep++;
        }
      });
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
}

/// Back button and screen name in one smoked-glass pill. It stays put while
/// the page scrolls, so it is frosted and dark enough to read over the
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

/// A small smoked-glass disc that marks a cover as playable.
class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.ink.withValues(alpha: 0.62),
        border: Border.all(color: Colors.white.withValues(alpha: 0.38)),
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: 22,
      ),
    );
  }
}

/// A step's place in the sequence: mint once it is done, indigo while it
/// is the one to do next, quiet until then.
class _StepMarker extends StatelessWidget {
  final int number;
  final bool completed;
  final bool active;

  const _StepMarker({
    required this.number,
    required this.completed,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final Gradient? gradient = completed
        ? AppGradients.mint
        : active
        ? AppGradients.indigo
        : null;
    final Color foreground = completed
        ? AppColors.ink
        : active
        ? Colors.white
        : AppColors.textMuted;

    return AnimatedContainer(
      duration: AppMotion.medium,
      curve: AppMotion.emphasized,
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
        color: gradient == null ? Colors.white.withValues(alpha: 0.8) : null,
        border: gradient == null
            ? Border.all(color: AppColors.lineStrong, width: 1.4)
            : null,
        boxShadow: completed
            ? AppShadows.glow(AppColors.mint, strength: 0.28)
            : const [],
      ),
      child: Text(
        '$number',
        style: AppText.display(size: 16, color: foreground),
      ),
    );
  }
}

/// A round icon button for light glass, where [GlassIconButton]'s white
/// glyph would vanish.
class _QuietIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _QuietIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.9,
        semanticLabel: tooltip,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.ink.withValues(alpha: 0.06),
          ),
          child: Icon(icon, color: AppColors.text, size: 22),
        ),
      ),
    );
  }
}
