import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/actualite_provider.dart';
import '../models/blog_post.dart';
import '../design/design.dart';
import 'actualite_details_screen.dart';
import 'custom_page_screen.dart';
import '../widgets/bottom_navigation_bar.dart';

class ActualitesScreen extends StatefulWidget {
  const ActualitesScreen({super.key});

  @override
  State<ActualitesScreen> createState() => _ActualitesScreenState();
}

class _ActualitesScreenState extends State<ActualitesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  // The category pills, in tab order.
  static const List<String> _tabLabels = [
    'Actualités Produits',
    'Actualités Scientifiques',
    'Vie de l\'entreprise – Événements',
  ];
  final List<GlobalKey> _pillKeys = List.generate(3, (_) => GlobalKey());
  int _revealedTab = 0;

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
    print('[ActualitesScreen] Initializing actualites screen');
    _tabController = TabController(length: 3, vsync: this);

    // Initialize the provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('[ActualitesScreen] Initializing ActualiteProvider');
      Provider.of<ActualiteProvider>(context, listen: false).initialize();
    });
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
      currentIndex: 3, // Actualites tab index
      onTap: (index) {},
      child: Consumer<ActualiteProvider>(
        builder: (context, actualiteProvider, child) {
          // The wrapper paints the pastel canvas; this page only adds the
          // ink hero and lets its lists run under the glass dock.
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Column(
              children: [
                _buildHeader(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _ActualiteCategoryTabView(
                        category: 'Actualités produits',
                        cardBuilder: (actualite, index) =>
                            _buildArrivingCard(actualite, index),
                        errorBuilder: () =>
                            _buildErrorState(actualiteProvider),
                        emptyBuilder: () =>
                            _buildEmptyState('Actualités produits'),
                      ),
                      _ActualiteCategoryTabView(
                        category: 'Actualités scientifiques',
                        cardBuilder: (actualite, index) =>
                            _buildArrivingCard(actualite, index),
                        errorBuilder: () =>
                            _buildErrorState(actualiteProvider),
                        emptyBuilder: () =>
                            _buildEmptyState('Actualités scientifiques'),
                      ),
                      _ActualiteCategoryTabView(
                        category: 'Vie de l\'entreprise - evenements',
                        cardBuilder: (actualite, index) =>
                            _buildArrivingCard(actualite, index),
                        errorBuilder: () =>
                            _buildErrorState(actualiteProvider),
                        emptyBuilder: () => _buildEmptyState(
                          'Vie de l\'entreprise - evenements',
                        ),
                      ),
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
                    'Actualités',
                    style: AppText.display(size: 30, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Restez informé des dernières actualités',
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
                hintText: 'Rechercher une actualité...',
                onChanged: (value) {
                  Provider.of<ActualiteProvider>(
                    context,
                    listen: false,
                  ).searchActualites(value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The three categories as filter pills on the canvas. They share the
  /// controller the pages swipe with, so a swipe selects its pill and
  /// brings it into view.
  Widget _buildTabBar() {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        final selected = _tabController.index;
        if (selected != _revealedTab) {
          _revealedTab = selected;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final pill = _pillKeys[selected].currentContext;
            if (pill == null) return;
            Scrollable.ensureVisible(
              pill,
              alignment: 0.5,
              duration: AppMotion.medium,
              curve: AppMotion.emphasized,
            );
          });
        }
        return Entrance(
          delay: const Duration(milliseconds: 140),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              14,
              AppSpace.page,
              10,
            ),
            child: Row(
              children: [
                for (var i = 0; i < _tabLabels.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  SelectPill(
                    key: _pillKeys[i],
                    label: _tabLabels[i],
                    selected: i == selected,
                    onTap: () => _tabController.animateTo(i),
                  ),
                ],
              ],
            ),
          ),
        );
      },
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

  /// The first screenful lifts into place once, when the first list shows.
  /// Cards built later (scrolling, paging, the other categories) appear in
  /// place.
  Widget _buildArrivingCard(BlogPost actualite, int index) {
    // Newest first, so the latest story leads with a taller cover.
    final card = _buildActualiteCard(actualite, featured: index == 0);
    if (!_listArrived && !_arrivalScheduled) {
      _arrivalScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _listArrived = true);
    }
    if (index >= _staggeredItems) return card;
    final settled = _listArrived;
    return Entrance(
      delay: settled
          ? Duration.zero
          : Duration(milliseconds: 200 + 70 * index),
      duration: settled ? Duration.zero : AppMotion.slow,
      child: card,
    );
  }

  Widget _buildActualiteCard(BlogPost actualite, {bool featured = false}) {
    final excerpt = actualite.excerpt;
    final date = _formatDate(actualite.createdAt);

    return _centered(
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: SoftCard(
          padding: EdgeInsets.zero,
          semanticLabel: actualite.title,
          onTap: () {
            if (actualite.isCustomPage) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CustomPageScreen(customPageId: actualite.id),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ActualiteDetailsScreen(actualite: actualite),
                ),
              );
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Section, clipped by the card's own top corners.
              if (actualite.coverImageUrl != null &&
                  actualite.coverImageUrl!.isNotEmpty)
                SizedBox(
                  height: featured ? 208 : 156,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: actualite.coverImageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const SizedBox.expand(
                          child: Shimmer(child: SkeletonBox(radius: 0)),
                        ),
                        errorWidget: (context, url, error) =>
                            const ColoredBox(
                              color: AppColors.indigoTint,
                              child: Center(
                                child: Icon(
                                  Icons.image_not_supported_rounded,
                                  color: AppColors.lineStrong,
                                  size: 32,
                                ),
                              ),
                            ),
                      ),
                      if (actualite.hasVideo)
                        const Positioned(
                          top: 12,
                          right: 12,
                          child: _PlayBadge(),
                        ),
                    ],
                  ),
                ),

              // Content Section
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category and date
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TonePill(
                          label: actualite.actualiteCategory ?? 'Actualité',
                        ),
                        if (date.isNotEmpty)
                          TonePill(
                            label: date,
                            tone: _quietTone,
                            icon: Icons.schedule_rounded,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Title
                    Text(
                      actualite.title,
                      style: AppText.display(
                        size: featured ? 21 : 18,
                        height: 1.15,
                      ),
                      maxLines: featured ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Excerpt
                    if (excerpt != null && excerpt.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        excerpt,
                        style: AppText.body(
                          size: 14.5,
                          color: AppColors.textMuted,
                        ),
                        maxLines: featured ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // Action buttons - only show if media is available
                    _buildActionButtonsSection(actualite),

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
                            actualite.author ?? 'Admin',
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
            ],
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

  Widget _buildErrorState(ActualiteProvider provider) {
    return _buildStateArea(
      EmptyState(
        icon: Icons.error_outline_rounded,
        tone: Tone.coral,
        title: 'Oups ! Une erreur s\'est produite',
        message: 'Impossible de charger les actualités.\nVeuillez réessayer.',
        actionLabel: 'Réessayer',
        onAction: provider.refresh,
      ),
    );
  }

  Widget _buildEmptyState(String category) {
    return _buildStateArea(
      EmptyState(
        icon: Icons.article_rounded,
        title: 'Aucune actualité disponible',
        message:
            'Il n\'y a pas encore d\'actualités\ndans la catégorie "$category".',
        actionLabel: 'Actualiser',
        onAction: () {
          Provider.of<ActualiteProvider>(
            context,
            listen: false,
          ).refresh();
        },
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m';
      }
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}j';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildActionButtonsSection(BlogPost actualite) {
    // Collect available action buttons
    final List<Widget> buttons = [
      // Video button
      if (actualite.hasVideo)
        _buildActionButton(
          'Regarder la vidéo',
          Icons.play_circle_outline_rounded,
          () => _showVideoDialog(actualite),
        ),
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

  /// A quiet glass pill for a card's secondary action: 36pt tall, in a
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

  void _showVideoDialog(BlogPost actualite) async {
    if (!actualite.hasVideo) {
      _showSnackBar('Aucune vidéo disponible pour cette actualité');
      return;
    }

    final videoUrl = actualite.videoUrl;
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

class _ActualiteCategoryTabView extends StatefulWidget {
  final String category;
  final Widget Function(BlogPost actualite, int index) cardBuilder;
  final Widget Function() errorBuilder;
  final Widget Function() emptyBuilder;

  const _ActualiteCategoryTabView({
    required this.category,
    required this.cardBuilder,
    required this.errorBuilder,
    required this.emptyBuilder,
  });

  @override
  State<_ActualiteCategoryTabView> createState() =>
      _ActualiteCategoryTabViewState();
}

class _ActualiteCategoryTabViewState extends State<_ActualiteCategoryTabView> {
  late ScrollController _scrollController;
  bool _showScrollIndicator = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final extentAfter = _scrollController.position.extentAfter;

    // Trigger loadMore when scrolling near bottom (within 200px)
    if (currentScroll >= maxScroll - 200) {
      final provider = Provider.of<ActualiteProvider>(context, listen: false);
      provider.loadMoreActualites(widget.category);
    }

    // Toggle scroll indicator visibility:
    // Show only when user is near the top and there's scrollable content remaining
    final shouldShow = currentScroll < 120 && extentAfter > 60;
    if (shouldShow != _showScrollIndicator) {
      setState(() {
        _showScrollIndicator = shouldShow;
      });
    }
  }

  void _scrollToNext() {
    if (_scrollController.hasClients) {
      final target = _scrollController.offset + 380;
      _scrollController.animateTo(
        target.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Placeholders with the cards' own silhouette: cover, pills, title.
  Widget _buildLoadingSkeleton(EdgeInsets padding) {
    Widget card(double cover) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(height: cover, radius: AppRadii.lg),
              const SizedBox(height: 14),
              const SkeletonBox(width: 132, height: 24, radius: AppRadii.pill),
              const SizedBox(height: 12),
              const SkeletonBox(height: 20),
              const SizedBox(height: 8),
              const SkeletonBox(width: 190, height: 14),
            ],
          ),
        ),
      ),
    );

    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        children: [card(208), card(156)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ActualiteProvider>(context);

    // The list runs under the glass dock; this is the room it needs to clear.
    final dock = MediaQuery.paddingOf(context).bottom;
    final listPadding = EdgeInsets.fromLTRB(
      AppSpace.page,
      6,
      AppSpace.page,
      dock + 20,
    );

    if (provider.isLoadingCategory(widget.category) &&
        provider.getActualitesByCategory(widget.category).isEmpty) {
      return _buildLoadingSkeleton(listPadding);
    }

    if (provider.hasError) {
      return widget.errorBuilder();
    }

    final actualites = provider.getActualitesByCategory(widget.category);

    if (actualites.isEmpty) {
      return widget.emptyBuilder();
    }

    final isLoadingMore = provider.isLoadingMoreCategory(widget.category);

    // Display scroll indicator ONLY if there are MORE THAN 1 item
    // AND the user hasn't scrolled to the bottom of the list
    final bool isAtEnd =
        _scrollController.hasClients &&
        _scrollController.position.extentAfter <= 60;
    final bool canShowIndicator =
        actualites.length > 1 && _showScrollIndicator && !isAtEnd;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            await provider.loadInitialCategory(widget.category);
          },
          color: AppColors.indigo,
          child: ListView.builder(
            controller: _scrollController,
            padding: listPadding,
            itemCount: actualites.length + (isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < actualites.length) {
                return widget.cardBuilder(actualites[index], index);
              } else {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CapsuleLoader(size: 38)),
                );
              }
            },
          ),
        ),

        // Scroll-down hint: a smoked pill resting just above the dock. It
        // fades with the same rule as before and no longer bounces.
        Positioned(
          bottom: dock + 10,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: canShowIndicator ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: IgnorePointer(
              ignoring: !canShowIndicator,
              child: Center(
                child: Pressable(
                  onTap: _scrollToNext,
                  semanticLabel: 'Défiler vers le bas',
                  child: Glass(
                    style: GlassStyle.smoked,
                    height: 44,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Défiler vers le bas',
                          style: AppText.label(
                            weight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.keyboard_double_arrow_down_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
