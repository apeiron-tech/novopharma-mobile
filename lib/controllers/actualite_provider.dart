import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/blog_post.dart';

class ActualiteProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<BlogPost> _actualites = [];
  List<BlogPost> _filteredActualites = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  // Getters
  List<BlogPost> get actualites => _filteredActualites;
  bool get isLoading => _isLoading;
  bool get hasError => _error != null;
  String? get error => _error;
  bool get hasActualites => _filteredActualites.isNotEmpty;

  // Category mappings for Firebase
  final Map<String, String> _categoryMappings = {
    'Actualités produits': 'Actualités produits',
    'Actualités scientifiques': 'Actualités scientifiques',
    'Vie de l\'entreprise - evenements': 'Vie de l\'entreprise - evenements',
  };

  Future<void> initialize() async {
    await loadActualites();
  }

  Future<void> loadActualites() async {
    try {
      print('[ActualiteProvider] Starting to load actualites...');
      _setLoading(true);
      _error = null;

      // First, let's check if we can connect to Firebase at all
      print('[ActualiteProvider] Testing Firebase connection...');

      // Try to get all documents first to see if Firebase is accessible
      final testQuery = await _firestore.collection('blogPosts').limit(1).get();
      print(
        '[ActualiteProvider] Firebase test query returned ${testQuery.docs.length} docs',
      );

      // Listen to real-time updates from Firestore
      print('[ActualiteProvider] Setting up real-time listener...');

      // Let's try a simpler query first - get all blogPosts
      _firestore
          .collection('blogPosts')
          .snapshots()
          .listen(
            (snapshot) {
              try {
                print(
                  '[ActualiteProvider] Received ${snapshot.docs.length} documents from Firestore',
                );

                _actualites = snapshot.docs
                    .map((doc) {
                      print(
                        '[ActualiteProvider] Processing document: ${doc.id}',
                      );
                      final data = doc.data() as Map<String, dynamic>?;
                      if (data == null) {
                        print(
                          '[ActualiteProvider] Document ${doc.id} has no data',
                        );
                        return null;
                      }

                      print('[ActualiteProvider] Document data: $data');
                      print(
                        '[ActualiteProvider] Document type: ${data['type']}, isPublished: ${data['isPublished']}',
                      );

                      return BlogPost.fromFirestore(doc);
                    })
                    .where((actualite) => actualite != null)
                    .cast<BlogPost>()
                    .where((actualite) {
                      final isActualite = actualite.type == 'actualité';
                      final isPublished = actualite.isPublished;
                      print(
                        '[ActualiteProvider] Article \"${actualite.title}\" - type: ${actualite.type}, isPublished: $isPublished, category: ${actualite.actualiteCategory}',
                      );
                      return isActualite && isPublished;
                    })
                    .toList();

                print(
                  '[ActualiteProvider] Filtered actualites count: ${_actualites.length}',
                );
                _applyFilters();
                _setLoading(false);
              } catch (e) {
                print('[ActualiteProvider] Error processing documents: $e');
                print('[ActualiteProvider] Stack trace: ${StackTrace.current}');
                _handleError('Erreur lors de la lecture des données: $e');
              }
            },
            onError: (error) {
              print('[ActualiteProvider] Firestore error: $error');
              _handleError('Erreur de connexion: $error');
            },
          );
    } catch (e) {
      print('[ActualiteProvider] Error loading actualites: $e');
      _handleError('Erreur lors du chargement des actualités: $e');
    }
  }

  List<BlogPost> getActualitesByCategory(String category) {
    final mappedCategory = _categoryMappings[category] ?? category;
    print(
      '[ActualiteProvider] Getting actualites for category: $category (mapped: $mappedCategory)',
    );
    print(
      '[ActualiteProvider] Total filtered actualites: ${_filteredActualites.length}',
    );

    final result = _filteredActualites.where((actualite) {
      final matches = actualite.actualiteCategory == mappedCategory;
      print(
        '[ActualiteProvider] Article "${actualite.title}" category "${actualite.actualiteCategory}" matches $mappedCategory: $matches',
      );
      return matches;
    }).toList();

    print(
      '[ActualiteProvider] Returning ${result.length} articles for category $category',
    );
    return result;
  }

  void searchActualites(String query) {
    _searchQuery = query.toLowerCase().trim();
    _applyFilters();
  }

  void _applyFilters() {
    print(
      '[ActualiteProvider] Applying filters. Search query: "$_searchQuery"',
    );
    print(
      '[ActualiteProvider] Total actualites before filtering: ${_actualites.length}',
    );

    if (_searchQuery.isEmpty) {
      _filteredActualites = List.from(_actualites);
    } else {
      _filteredActualites = _actualites.where((actualite) {
        return actualite.title.toLowerCase().contains(_searchQuery) ||
            (actualite.content.toLowerCase().contains(_searchQuery)) ||
            (actualite.excerpt?.toLowerCase().contains(_searchQuery) ??
                false) ||
            (actualite.author?.toLowerCase().contains(_searchQuery) ?? false) ||
            (actualite.actualiteCategory?.toLowerCase().contains(
                  _searchQuery,
                ) ??
                false);
      }).toList();
    }

    print(
      '[ActualiteProvider] Filtered actualites count: ${_filteredActualites.length}',
    );
    notifyListeners();
  }

  Future<void> refresh() async {
    await loadActualites();
  }

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _handleError(String error) {
    _error = error;
    _isLoading = false;
    notifyListeners();

    // Auto-clear error after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (_error == error) {
        _error = null;
        notifyListeners();
      }
    });
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
