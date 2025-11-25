import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../controllers/actualite_provider.dart';
import '../models/blog_post.dart';
import '../theme.dart';
import 'actualite_details_screen.dart';
import 'dashboard_home_screen.dart';
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
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              LightModeColors.novoPharmaBlue,
              LightModeColors.novoPharmaBlue.withValues(alpha: 0.8),
              Colors.white,
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
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
                    _buildActualiteTab('Actualités produits'),
                    _buildActualiteTab('Actualités scientifiques'),
                    _buildActualiteTab('Vie de l\'entreprise - evenements'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: IconButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const DashboardHomeScreen(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Actualités',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 28,
                          ),
                    ),
                    Text(
                      'Restez informé des dernières actualités',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Decorative elements
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: const Icon(
                  Icons.article_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              onChanged: (value) {
                Provider.of<ActualiteProvider>(
                  context,
                  listen: false,
                ).searchActualites(value);
              },
              decoration: InputDecoration(
                hintText: 'Rechercher une actualité...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.white.withValues(alpha: 0.8),
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
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: LightModeColors.novoPharmaBlue,
          indicator: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                LightModeColors.novoPharmaBlue,
                LightModeColors.novoPharmaBlue.withValues(alpha: 0.8),
              ],
            ),
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

  Widget _buildActualiteTab(String category) {
    return Consumer<ActualiteProvider>(
      builder: (context, provider, child) {
        print('[ActualitesScreen] Building tab for category: $category');
        print(
          '[ActualitesScreen] Provider state - loading: ${provider.isLoading}, hasError: ${provider.hasError}',
        );

        if (provider.isLoading) {
          print('[ActualitesScreen] Showing loading indicator');
          return const Center(
            child: CircularProgressIndicator(
              color: LightModeColors.novoPharmaBlue,
            ),
          );
        }

        if (provider.hasError) {
          print('[ActualitesScreen] Showing error state: ${provider.error}');
          return _buildErrorState(provider);
        }

        final actualites = provider.getActualitesByCategory(category);
        print(
          '[ActualitesScreen] Got ${actualites.length} actualites for category $category',
        );

        if (actualites.isEmpty) {
          print(
            '[ActualitesScreen] Showing empty state for category $category',
          );
          return _buildEmptyState(category);
        }

        return RefreshIndicator(
          onRefresh: provider.refresh,
          color: LightModeColors.novoPharmaBlue,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: actualites.length,
            itemBuilder: (context, index) {
              return _buildActualiteCard(actualites[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildActualiteCard(BlogPost actualite) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
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
                          LightModeColors.novoPharmaBlue.withValues(alpha: 0.1),
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
                        color: Colors.grey[100],
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: LightModeColors.novoPharmaBlue,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[100],
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.grey[400],
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
                            LightModeColors.novoPharmaBlue.withValues(
                              alpha: 0.1,
                            ),
                            LightModeColors.novoPharmaBlue.withValues(
                              alpha: 0.05,
                            ),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: LightModeColors.novoPharmaBlue.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      child: Text(
                        actualite.actualiteCategory ?? 'Actualité',
                        style: const TextStyle(
                          color: LightModeColors.novoPharmaBlue,
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
                        color: Colors.black87,
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
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),

                    const SizedBox(height: 16),

                    // Meta Information
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: LightModeColors.novoPharmaBlue.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.person_outline,
                            size: 14,
                            color: LightModeColors.novoPharmaBlue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          actualite.author ?? 'Admin',
                          style: const TextStyle(
                            fontSize: 12,
                            color: LightModeColors.novoPharmaBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(actualite.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
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
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Oups ! Une erreur s\'est produite',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Impossible de charger les actualités.\nVeuillez réessayer.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: provider.refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: LightModeColors.novoPharmaBlue,
                foregroundColor: Colors.white,
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
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
                color: LightModeColors.novoPharmaBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.article_outlined,
                size: 48,
                color: LightModeColors.novoPharmaBlue,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune actualité disponible',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Il n\'y a pas encore d\'actualités\ndans la catégorie "$category".',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
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
                foregroundColor: LightModeColors.novoPharmaBlue,
                side: const BorderSide(color: LightModeColors.novoPharmaBlue),
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
}
