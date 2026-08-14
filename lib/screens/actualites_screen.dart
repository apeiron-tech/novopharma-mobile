import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/actualite_provider.dart';
import '../models/blog_post.dart';
import '../theme.dart';
import 'actualite_details_screen.dart';
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
          return Scaffold(
            body: Container(
              decoration: BoxDecoration(
                color: LightModeColors.lightSurfaceVariant,
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    _buildHeader(),
                    _buildTabBar(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _ActualiteCategoryTabView(
                            category: 'Actualités produits',
                            cardBuilder: (actualite) =>
                                _buildActualiteCard(actualite),
                            errorBuilder: () =>
                                _buildErrorState(actualiteProvider),
                            emptyBuilder: () =>
                                _buildEmptyState('Actualités produits'),
                          ),
                          _ActualiteCategoryTabView(
                            category: 'Actualités scientifiques',
                            cardBuilder: (actualite) =>
                                _buildActualiteCard(actualite),
                            errorBuilder: () =>
                                _buildErrorState(actualiteProvider),
                            emptyBuilder: () =>
                                _buildEmptyState('Actualités scientifiques'),
                          ),
                          _ActualiteCategoryTabView(
                            category: 'Vie de l\'entreprise - evenements',
                            cardBuilder: (actualite) =>
                                _buildActualiteCard(actualite),
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
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            LightModeColors.novoPharmaBlue,
            LightModeColors.novoPharmaBlue.withValues(alpha: 0.8),
            LightModeColors.lightSecondary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: LightModeColors.novoPharmaBlue.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Main content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: LightModeColors.lightOnPrimary.withValues(
                        alpha: 0.2,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: LightModeColors.lightOnPrimary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.article_rounded,
                      color: LightModeColors.lightOnPrimary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Actualités',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: LightModeColors.lightOnPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Restez informé des dernières actualités',
                          style: TextStyle(
                            fontSize: 14,
                            color: LightModeColors.lightOnPrimary.withOpacity(
                              0.7,
                            ), // 70% opacity of white
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: LightModeColors.lightOnPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: LightModeColors.lightOnPrimary.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(
                    color: LightModeColors.lightOnPrimaryContainer,
                  ),
                  onChanged: (value) {
                    Provider.of<ActualiteProvider>(
                      context,
                      listen: false,
                    ).searchActualites(value);
                  },
                  decoration: InputDecoration(
                    hintText: 'Rechercher une actualité...',
                    hintStyle: TextStyle(
                      color: LightModeColors.lightOnPrimaryContainer
                          .withOpacity(0.7), // 70% opacity of white
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: LightModeColors.lightOnPrimaryContainer
                          .withOpacity(0.8), // 80% opacity of white
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LightModeColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: LightModeColors.lightSurfaceVariant.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: TabBar(
          controller: _tabController,
          labelColor: LightModeColors.lightOnPrimary,
          unselectedLabelColor: LightModeColors.lightError,
          indicator: BoxDecoration(
            color: LightModeColors.lightError,
            borderRadius: BorderRadius.circular(20),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          tabs: const [
            Tab(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Actualités\nProduits',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Tab(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Actualités\nScientifiques',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Tab(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Vie de l\'entreprise\nÉvénements',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActualiteCard(BlogPost actualite) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: LightModeColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: LightModeColors.lightOnPrimary.withOpacity(0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: LightModeColors.lightSurfaceVariant.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ActualiteDetailsScreen(actualite: actualite),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Section
              if (actualite.coverImageUrl != null &&
                  actualite.coverImageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          LightModeColors.lightPrimary.withOpacity(0.1),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: actualite.coverImageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: LightModeColors.lightSurfaceVariant,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: LightModeColors.lightPrimary,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: LightModeColors.lightSurfaceVariant,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: LightModeColors.dashboardTextTertiary,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),

              // Content Section
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            LightModeColors.success.withOpacity(0.1),
                            LightModeColors.success.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: LightModeColors.success.withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        actualite.actualiteCategory ?? 'Actualité',
                        style: const TextStyle(
                          color: LightModeColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Title
                    Text(
                      actualite.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: LightModeColors.dashboardTextPrimary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Excerpt
                    if (actualite.excerpt != null &&
                        actualite.excerpt!.isNotEmpty)
                      Text(
                        actualite.excerpt!,
                        style: TextStyle(
                          fontSize: 14,
                          color: LightModeColors.dashboardTextSecondary,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),

                    const SizedBox(height: 16),

                    // Action buttons - only show if media is available
                    _buildActionButtonsSection(actualite),
                    // Meta Information
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: LightModeColors.warning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.person_outline,
                            size: 14,
                            color: LightModeColors.warning,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          actualite.author ?? 'Admin',
                          style: const TextStyle(
                            fontSize: 12,
                            color: LightModeColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: LightModeColors.lightSurfaceVariant
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: LightModeColors.dashboardTextSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(actualite.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: LightModeColors.dashboardTextSecondary,
                            fontWeight: FontWeight.w500,
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

  Widget _buildErrorState(ActualiteProvider provider) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: LightModeColors.lightSurface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: LightModeColors.lightSurfaceVariant.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: LightModeColors.lightError.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: LightModeColors.lightError,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Oups ! Une erreur s\'est produite',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: LightModeColors.dashboardTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Impossible de charger les actualités.\nVeuillez réessayer.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: LightModeColors.dashboardTextSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: provider.refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: LightModeColors.lightPrimary,
                foregroundColor: LightModeColors.lightSecondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String category) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: LightModeColors.lightSurface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: LightModeColors.lightSurfaceVariant.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: LightModeColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.article_outlined,
                size: 48,
                color: LightModeColors.warning,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune actualité disponible',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: LightModeColors.dashboardTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Il n\'y a pas encore d\'actualités\ndans la catégorie "$category".',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: LightModeColors.dashboardTextSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                Provider.of<ActualiteProvider>(
                  context,
                  listen: false,
                ).refresh();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Actualiser'),
              style: OutlinedButton.styleFrom(
                foregroundColor: LightModeColors.warning,
                side: const BorderSide(color: LightModeColors.warning),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
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
    List<Widget> topRowButtons = [];

    // Video button (first priority - top row)
    if (actualite.hasVideo) {
      topRowButtons.add(
        Expanded(
          child: _buildActionButton(
            'Regarder la vidéo',
            Icons.play_circle_outline,
            () => _showVideoDialog(actualite),
          ),
        ),
      );
    }

    // If no buttons available, return empty container
    if (topRowButtons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Row(children: topRowButtons),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: LightModeColors.lightError,
        side: BorderSide(color: LightModeColors.lightError),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        backgroundColor: LightModeColors.novoPharmaBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _ActualiteCategoryTabView extends StatefulWidget {
  final String category;
  final Widget Function(BlogPost actualite) cardBuilder;
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

class _ActualiteCategoryTabViewState extends State<_ActualiteCategoryTabView>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  bool _showScrollIndicator = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
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
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ActualiteProvider>(context);

    if (provider.isLoadingCategory(widget.category) &&
        provider.getActualitesByCategory(widget.category).isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: LightModeColors.lightPrimary),
      );
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
          color: LightModeColors.lightPrimary,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: actualites.length + (isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < actualites.length) {
                return widget.cardBuilder(actualites[index]);
              } else {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: LightModeColors.lightPrimary,
                    ),
                  ),
                );
              }
            },
          ),
        ),

        // Premium Animated scroll-down indicator
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: canShowIndicator ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: IgnorePointer(
              ignoring: !canShowIndicator,
              child: Center(
                child: AnimatedBuilder(
                  animation: _bounceAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _bounceAnimation.value),
                      child: child,
                    );
                  },
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _scrollToNext,
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              LightModeColors.novoPharmaBlue,
                              LightModeColors.lightPrimary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: LightModeColors.novoPharmaBlue.withValues(
                                alpha: 0.4,
                              ),
                              blurRadius: 16,
                              spreadRadius: 1,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'Défiler vers le bas',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
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
          ),
        ),
      ],
    );
  }
}
