import 'package:flutter/material.dart';
import 'package:novopharma/models/marque.dart';
import 'package:novopharma/services/marque_service.dart';
import 'package:novopharma/theme.dart';
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
      builder: (context) => MarqueDetailsPopup(marque: marque),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Assistance Marques',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: LightModeColors.dashboardTextPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: LightModeColors.dashboardTextPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Search Bar Header
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher une marque...',
                prefixIcon: const Icon(Icons.search, color: LightModeColors.lightPrimary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Marques Grid List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: LightModeColors.lightPrimary,
                    ),
                  )
                : _filteredMarques.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Aucune marque trouvée',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchMarques,
                        color: LightModeColors.lightPrimary,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.95,
                          ),
                          itemCount: _filteredMarques.length,
                          itemBuilder: (context, index) {
                            final marque = _filteredMarques[index];
                            return _buildMarqueCard(marque);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarqueCard(MarqueModel marque) {
    return GestureDetector(
      onTap: () => _showMarqueDetails(marque),
      child: Card(
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: marque.logo != null && marque.logo!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
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
              const SizedBox(height: 10),
              // Title
              Text(
                marque.marqueName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: LightModeColors.dashboardTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              // Category preview tag count
              Text(
                marque.contactList.isNotEmpty
                    ? '${marque.contactList.length} contact(s)'
                    : 'Aide & Info',
                style: TextStyle(
                  fontSize: 12,
                  color: marque.contactList.isNotEmpty
                      ? Colors.green.shade700
                      : Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoFallback(String marqueName) {
    return Center(
      child: Text(
        marqueName.isNotEmpty ? marqueName.substring(0, 1).toUpperCase() : 'M',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: LightModeColors.lightPrimary,
        ),
      ),
    );
  }
}
