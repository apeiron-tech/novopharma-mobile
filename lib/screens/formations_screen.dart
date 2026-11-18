import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:novopharma/widgets/bottom_navigation_bar.dart';
import 'package:novopharma/controllers/formation_provider.dart';
import 'package:novopharma/models/blog_post.dart';
import 'package:novopharma/screens/formation_details_screen.dart';
import 'package:novopharma/design/design.dart';

class FormationsScreen extends StatefulWidget {
  const FormationsScreen({super.key});

  @override
  State<FormationsScreen> createState() => _FormationsScreenState();
}

class _FormationsScreenState extends State<FormationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  // How many cards take part in the arrival, and whether it has played.
  static const int _staggeredItems = 6;
  bool _arrivalScheduled = false;
  bool _listArrived = false;

  /// A neutral pill for metadata that should not carry a feature colour.
  static const Tone _quietTone = Tone(
    AppColors.textFaint,
    AppColors.textMuted,
    AppColors.line,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationScaffoldWrapper(
      currentIndex: 1,
      onTap: (index) {},
      child: Consumer<FormationProvider>(
        builder: (context, formationProvider, child) {
          // The wrapper paints the pastel canvas; this page only adds the
          // ink hero and lets its lists run under the glass dock.
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMesFormationsTab(formationProvider),
                      _buildVideosTab(formationProvider),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Keeps content at a readable width on tablets.
  Widget _centered(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: child,
      ),
    );
  }

  /// Room for the last card to clear the dock the page scrolls under.
  EdgeInsets _listPadding(BuildContext context) {
    return EdgeInsets.fromLTRB(
      AppSpace.page,
      AppSpace.xl,
      AppSpace.page,
      MediaQuery.paddingOf(context).bottom + 20,
    );
  }

  Widget _buildHeader() {
    return InkHero(
      padding: const EdgeInsets.fromLTRB(AppSpace.page, 10, AppSpace.page, 22),
      child: _centered(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Entrance(
              offset: const Offset(0, -12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Formation',
                    style: AppText.display(size: 30, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Développez vos compétences',
                    style: AppText.body(
                      size: 14.5,
                      weight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Entrance(
              delay: const Duration(milliseconds: 80),
              child: AppSearchField(
                controller: _searchController,
                onDark: true,
                hintText: 'Rechercher une formation...',
                onChanged: (value) {
                  Provider.of<FormationProvider>(
                    context,
                    listen: false,
                  ).searchFormations(value);
                },
              ),
            ),
            const SizedBox(height: 12),
            Entrance(
              delay: const Duration(milliseconds: 140),
              child: _buildTabBar(),
            ),
          ],
        ),
      ),
    );
  }

  /// The two views of the catalogue, on the same controller the pages
  /// swipe with, so the thumb follows a swipe as well as a tap.
  Widget _buildTabBar() {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) => SegmentedTabs(
        labels: const ['Mes Formations', 'Vidéos'],
        selectedIndex: _tabController.index,
        onChanged: _tabController.animateTo,
        onDark: true,
      ),
    );
  }

  Widget _buildMesFormationsTab(FormationProvider provider) {
    if (provider.isLoading) {
      return _buildLoadingSkeleton();
    }

    if (provider.hasError) {
      return _buildErrorState(provider);
    }

    if (!provider.hasFormations) {
      return _buildEmptyState();
    }

    _markListArrived();
    return RefreshIndicator(
      onRefresh: provider.refresh,
      color: AppColors.indigo,
      child: ListView.builder(
        padding: _listPadding(context),
        itemCount: provider.formations.length,
        itemBuilder: (context, index) {
          // Newest first, so the latest formation leads with a taller cover.
          return _arriving(
            index,
            _buildFormationCard(
              provider.formations[index],
              featured: index == 0,
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideosTab(FormationProvider provider) {
    if (provider.isLoading) {
      return SkeletonList(
        count: 4,
        itemHeight: 112,
        padding: _listPadding(context),
      );
    }

    final formationsWithVideos = provider.formations
        .where((formation) => formation.hasVideo)
        .toList();

    if (formationsWithVideos.isEmpty) {
      return _buildEmptyVideoState();
    }

    return ListView.builder(
      padding: _listPadding(context),
      itemCount: formationsWithVideos.length,
      itemBuilder: (context, index) {
        return _buildVideoCard(formationsWithVideos[index]);
      },
    );
  }

  /// The first screenful lifts into place once, when the catalogue first
  /// shows. Cards built later (scrolling, refreshes, the other tab) appear
  /// in place.
  void _markListArrived() {
    if (_listArrived || _arrivalScheduled) return;
    _arrivalScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _listArrived = true);
  }

  Widget _arriving(int index, Widget child) {
    if (index >= _staggeredItems) return child;
    final settled = _listArrived;
    return Entrance(
      delay: settled
          ? Duration.zero
          : Duration(milliseconds: 200 + 70 * index),
      duration: settled ? Duration.zero : AppMotion.slow,
      child: child,
    );
  }

  /// Placeholders with the cards' own silhouette: cover, pills, title.
  Widget _buildLoadingSkeleton() {
    Widget card(double cover) => Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(height: cover, radius: AppRadii.lg),
          const SizedBox(height: 14),
          const SkeletonBox(width: 104, height: 24, radius: AppRadii.pill),
          const SizedBox(height: 12),
          const SkeletonBox(height: 20),
          const SizedBox(height: 8),
          const SkeletonBox(width: 190, height: 14),
        ],
      ),
    );

    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: _listPadding(context),
        children: [_centered(card(208)), _centered(card(152))],
      ),
    );
  }

  Widget _coverImage(String imageUrl) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => const SizedBox.expand(
        child: Shimmer(child: SkeletonBox(radius: 0)),
      ),
      errorWidget: (context, url, error) =>
          const _CoverFallback(icon: Icons.image_not_supported_rounded),
    );
  }

  Widget _buildFormationCard(BlogPost formation, {bool featured = false}) {
    final excerpt = formation.excerpt;

    return _centered(
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: SoftCard(
          padding: EdgeInsets.zero,
          onTap: () => _startFormation(formation),
          semanticLabel: formation.title,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover image, clipped by the card's own top corners.
              if (formation.coverImage != null)
                SizedBox(
                  height: featured ? 208 : 152,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _coverImage(formation.coverImage!),
                      if (formation.hasVideo)
                        const Positioned(
                          top: 12,
                          right: 12,
                          child: _PlayBadge(),
                        ),
                    ],
                  ),
                ),

              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // What it is, when it runs, what it ends with.
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        const TonePill(
                          label: 'Formation',
                          icon: Icons.school_rounded,
                        ),
                        if (formation.startDate != null)
                          TonePill(
                            label: formation.formattedStartDate,
                            tone: Tone.mint,
                            icon: Icons.event_rounded,
                          ),
                        if (formation.endDate != null)
                          TonePill(
                            label: 'Fin: ${formation.formattedEndDate}',
                            tone: _quietTone,
                            icon: Icons.schedule_rounded,
                          ),
                        if (formation.hasQuiz)
                          const TonePill(
                            label: 'Quiz de validation',
                            tone: Tone.amber,
                            icon: Icons.quiz_rounded,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      formation.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.display(
                        size: featured ? 21 : 18,
                        height: 1.15,
                      ),
                    ),
                    if (excerpt != null && excerpt.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        excerpt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(
                          size: 14.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_rounded,
                          size: 16,
                          color: AppColors.textFaint,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Speaker',
                                  style: AppText.label(letterSpacing: 0),
                                ),
                                const TextSpan(text: '  '),
                                TextSpan(
                                  text: formation.author ?? 'N/A',
                                  style: AppText.label(
                                    weight: FontWeight.w700,
                                    color: AppColors.text,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // Action buttons - only show if media is available
                    _buildActionButtonsSection(formation),

                    const SizedBox(height: 10),

                    // The whole card opens the formation; this line says so.
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Commencer la formation',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.label(
                              size: 14.5,
                              weight: FontWeight.w700,
                              color: AppColors.indigo,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: AppColors.indigoTint,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 20,
                            color: AppColors.indigoDeep,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtonsSection(BlogPost formation) {
    // Collect available action buttons
    final List<Widget> buttons = [
      // Video button (first priority)
      if (formation.hasVideo)
        _buildActionButton(
          'Regarder la vidéo',
          Icons.play_circle_outline_rounded,
          () => _showVideoDialog(formation),
        ),

      // PDF button (second priority)
      if (formation.hasPdf)
        _buildActionButton(
          'Fiche PDF',
          Icons.picture_as_pdf_rounded,
          () => _downloadPDF(formation),
        ),

      // Clinical study button (third priority)
      if (formation.hasClinicalStudy)
        _buildActionButton(
          'Étude clinique',
          Icons.science_rounded,
          () => _viewClinicalStudy(formation),
        ),

      // The quiz is taken from the formation itself, so here it is shown
      // as a pill beside the dates rather than as a button that does nothing.
    ];

    // If no buttons available, return empty container
    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(spacing: 8, children: buttons),
    );
  }

  /// A quiet glass pill for a card's secondary actions: 36pt tall, in a
  /// 44pt touch target.
  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return Pressable(
      onTap: onPressed,
      pressedScale: 0.94,
      semanticLabel: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: AppColors.lineStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: AppColors.indigoDeep),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppText.label(
                  weight: FontWeight.w700,
                  color: AppColors.indigoDeep,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoCard(BlogPost formation) {
    return _centered(
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: SoftCard(
          padding: EdgeInsets.zero,
          onTap: () => _showVideoDialog(formation),
          semanticLabel: formation.title,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Thumbnail, clipped by the card's own left corners. Its
                // children are positioned so the text sets the row's height.
                SizedBox(
                  width: 118,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: formation.coverImage != null
                            ? _coverImage(formation.coverImage!)
                            : const _CoverFallback(
                                icon: Icons.video_library_rounded,
                              ),
                      ),
                      const Positioned.fill(
                        child: Center(child: _PlayBadge()),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 112),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const TonePill(
                            label: 'Vidéo',
                            icon: Icons.play_circle_outline_rounded,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            formation.title,
                            style: AppText.display(size: 16.5, height: 1.15),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Par ${formation.author ?? 'N/A'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(
                              size: 13.5,
                              color: AppColors.textMuted,
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
      ),
    );
  }

  /// Centres a message in the space above the dock, and lets it scroll
  /// when the keyboard leaves too little room for it.
  Widget _buildStateArea(Widget child) {
    final dock = MediaQuery.paddingOf(context).bottom;
    return LayoutBuilder(
      builder: (context, constraints) {
        final room = constraints.maxHeight - dock;
        return SingleChildScrollView(
          padding: EdgeInsets.only(bottom: dock),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: room > 0 ? room : 0),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildErrorState(FormationProvider provider) {
    return _buildStateArea(
      EmptyState(
        icon: Icons.error_outline_rounded,
        tone: Tone.coral,
        title: 'Erreur de chargement',
        message: provider.error ?? 'Une erreur s\'est produite',
        actionLabel: 'Réessayer',
        onAction: provider.refresh,
      ),
    );
  }

  Widget _buildEmptyState() {
    return _buildStateArea(
      const EmptyState(
        icon: Icons.school_rounded,
        title: 'Aucune formation disponible',
        message:
            'Les formations apparaîtront ici dès qu\'elles seront publiées',
      ),
    );
  }

  Widget _buildEmptyVideoState() {
    return _buildStateArea(
      const EmptyState(
        icon: Icons.video_library_rounded,
        title: 'Aucune vidéo disponible',
      ),
    );
  }

  // Action handlers
  void _startFormation(BlogPost formation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FormationDetailsScreen(formation: formation),
      ),
    );
  }

  void _showVideoDialog(BlogPost formation) async {
    if (!formation.hasVideo) {
      _showSnackBar('Aucune vidéo disponible pour cette formation');
      return;
    }

    final videoUrl = formation.videoUrl;
    if (videoUrl == null || videoUrl.isEmpty) {
      _showSnackBar('URL de la vidéo non disponible');
      return;
    }

    try {
      final Uri url = Uri.parse(videoUrl);
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        // Try with inAppBrowserView as fallback
        await launchUrl(url, mode: LaunchMode.inAppBrowserView);
      }
    } catch (e) {
      print('Error launching video: $e');
      print('Video URL: $videoUrl');
      _showSnackBar('Erreur lors de l\'ouverture de la vidéo');
    }
  }

  void _downloadPDF(BlogPost formation) {
    if (!formation.hasPdf) {
      _showSnackBar('Aucun PDF disponible pour cette formation');
      return;
    }

    final pdfUrl = formation.pdfUrl;
    if (pdfUrl != null) {
      // TODO: Implement PDF download/viewing
      // You can use url_launcher or pdf_viewer packages
      _showSnackBar('Ouverture du PDF: ${formation.title}');
    }
  }

  void _viewClinicalStudy(BlogPost formation) {
    if (!formation.hasClinicalStudy) {
      _showSnackBar('Aucune étude clinique disponible pour cette formation');
      return;
    }

    final studyUrl = formation.clinicalStudyUrl;
    if (studyUrl != null) {
      // TODO: Implement clinical study viewing
      _showSnackBar('Ouverture de l\'étude clinique: ${formation.title}');
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

/// What a cover shows when there is no image, or it failed to load.
class _CoverFallback extends StatelessWidget {
  final IconData icon;
  const _CoverFallback({required this.icon});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.indigoTint,
      child: Center(
        child: Icon(icon, size: 30, color: AppColors.lineStrong),
      ),
    );
  }
}
