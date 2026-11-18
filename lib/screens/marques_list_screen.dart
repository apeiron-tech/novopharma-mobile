import 'package:flutter/material.dart';
import 'package:novopharma/design/design.dart';
import 'package:novopharma/models/marque.dart';
import 'package:novopharma/services/marque_service.dart';
import 'package:novopharma/widgets/marque_details_popup.dart';

class MarquesListScreen extends StatefulWidget {
  const MarquesListScreen({super.key});

  @override
  State<MarquesListScreen> createState() => _MarquesListScreenState();
}

class _MarquesListScreenState extends State<MarquesListScreen> {
  final MarqueService _marqueService = MarqueService();
  final TextEditingController _searchController = TextEditingController();

  List<MarqueModel> _allMarques = [];
  List<MarqueModel> _filteredMarques = [];
  bool _isLoading = true;

  // The grid arrives once. Tiles built after the first screenful has landed
  // (scrolling back, searching) appear in place instead of animating again.
  bool _arrived = false;

  @override
  void initState() {
    super.initState();
    _fetchMarques();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchMarques() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final marques = await _marqueService.getMarques();
      setState(() {
        _allMarques = marques;
        _filteredMarques = marques;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading marques: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredMarques = _allMarques;
      } else {
        _filteredMarques = _allMarques
            .where((m) =>
                m.marqueName.toLowerCase().contains(query) ||
                m.contactList.any((c) =>
                    c.responsibleName.toLowerCase().contains(query) ||
                    (c.secteur != null &&
                        c.secteur!.toLowerCase().contains(query))))
            .toList();
      }
    });
  }

  void _showMarqueDetails(MarqueModel marque) {
    showDialog(
      context: context,
      barrierColor: AppColors.ink.withValues(alpha: 0.45),
      builder: (context) => MarqueDetailsPopup(marque: marque),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: InkAppBar(
        title: 'Assistance marques',
        onBack: () => Navigator.of(context).pop(),
        // Search Bar Header
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            child: AppSearchField(
              controller: _searchController,
              hintText: 'Rechercher une marque...',
              onDark: true,
            ),
          ),
        ),
      ),
      body: AppBackground(
        // Marques Grid List
        child: _isLoading
            ? _buildLoadingGrid()
            : _filteredMarques.isEmpty
                ? const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Aucune marque trouvée',
                  )
                : RefreshIndicator(
                    onRefresh: _fetchMarques,
                    color: AppColors.indigo,
                    child: Builder(
                      builder: (context) {
                        if (!_arrived) {
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _arrived = true,
                          );
                        }
                        return GridView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            AppSpace.page,
                            AppSpace.xl,
                            AppSpace.page,
                            bottomInset + 24,
                          ),
                          gridDelegate: _gridDelegate,
                          itemCount: _filteredMarques.length,
                          itemBuilder: (context, index) {
                            final marque = _filteredMarques[index];
                            final stagger = !_arrived && index < 8;
                            return Entrance(
                              delay: stagger
                                  ? Duration(milliseconds: 60 * index)
                                  : Duration.zero,
                              duration:
                                  stagger ? AppMotion.slow : Duration.zero,
                              child: _buildMarqueCard(marque),
                            );
                          },
                        );
                      },
                    ),
                  ),
      ),
    );
  }

  static const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    crossAxisSpacing: 14,
    mainAxisSpacing: 14,
    mainAxisExtent: 184,
  );

  /// Tiles in the shape of what is coming.
  Widget _buildLoadingGrid() {
    return Shimmer(
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpace.page),
        gridDelegate: _gridDelegate,
        itemCount: 6,
        itemBuilder: (_, __) => const SkeletonBox(
          height: double.infinity,
          radius: AppRadii.lg,
        ),
      ),
    );
  }

  Widget _buildMarqueCard(MarqueModel marque) {
    final hasContacts = marque.contactList.isNotEmpty;

    return SoftCard(
      onTap: () => _showMarqueDetails(marque),
      semanticLabel: marque.marqueName,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo, in a round white dome
          Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: AppShadows.card,
            ),
            child: ClipOval(
              child: marque.logo != null && marque.logo!.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.network(
                        marque.logo!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildLogoFallback(marque.marqueName),
                      ),
                    )
                  : _buildLogoFallback(marque.marqueName),
            ),
          ),
          // Title
          Expanded(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                marque.marqueName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.display(size: 17, height: 1.15),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Category preview tag count
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: TonePill(
              label: hasContacts
                  ? '${marque.contactList.length} contact(s)'
                  : 'Aide & Info',
              tone: hasContacts ? Tone.mint : Tone.indigo,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoFallback(String marqueName) {
    return Center(
      child: Text(
        marqueName.isNotEmpty ? marqueName.substring(0, 1).toUpperCase() : 'M',
        style: AppText.display(
          size: 26,
          color: AppColors.indigo,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
