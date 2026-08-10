import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/blog_post.dart';

class CategoryState {
  List<BlogPost> items = [];
  DocumentSnapshot? lastDocument;
  bool hasMore = true;
  bool isLoading = false;
  bool isLoadingMore = false;
  String? error;
}

class ActualiteProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int pageSize = 10;

  final Map<String, CategoryState> _categoryStates = {};
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  // Category mappings for Firebase
  final Map<String, String> _categoryMappings = {
    'Actualités produits': 'Actualités produits',
    'Actualités scientifiques': 'Actualités scientifique',
    'Vie de l\'entreprise - evenements': 'Vie de l\'entreprise/Événements',
  };

  ActualiteProvider() {
    for (final category in _categoryMappings.keys) {
      _categoryStates[category] = CategoryState();
    }
  }

  // Getters
  bool get isLoading => _isLoading;
  bool get hasError => _error != null;
  String? get error => _error;
  String get searchQuery => _searchQuery;

  CategoryState _getOrCreateState(String category) {
    return _categoryStates.putIfAbsent(category, () => CategoryState());
  }

  bool isLoadingCategory(String category) => _categoryStates[category]?.isLoading ?? false;
  bool isLoadingMoreCategory(String category) => _categoryStates[category]?.isLoadingMore ?? false;
  bool hasMoreCategory(String category) => _categoryStates[category]?.hasMore ?? true;

  Future<void> initialize() async {
    await loadActualites();
  }

  Future<void> loadActualites() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load initial batch of 10 items for each category
      final futures = _categoryMappings.keys.map((cat) => loadInitialCategory(cat));
      await Future.wait(futures);
    } catch (e) {
      print('[ActualiteProvider] Error loading actualites: $e');
      _error = 'Erreur lors du chargement des actualités: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadInitialCategory(String category) async {
    final state = _getOrCreateState(category);
    state.isLoading = true;
    state.error = null;
    state.items = [];
    state.lastDocument = null;
    state.hasMore = true;

    notifyListeners();

    try {
      final mappedCategory = _categoryMappings[category] ?? category;

      // Try ordered Firestore query
      try {
        final query = _firestore
            .collection('blogPosts')
            .where('type', isEqualTo: 'actualité')
            .where('isPublished', isEqualTo: true)
            .where('actualiteCategory', isEqualTo: mappedCategory)
            .orderBy('createdAt', descending: true)
            .limit(pageSize);

        final snapshot = await query.get();
        final docs = snapshot.docs.where((doc) {
          final data = doc.data();
          return data['status'] != 'DELETED';
        }).toList();

        state.items = docs.map((doc) => BlogPost.fromFirestore(doc)).toList();
        // Ensure strictly sorted newest first
        state.items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (snapshot.docs.isNotEmpty) {
          state.lastDocument = snapshot.docs.last;
        }
        state.hasMore = snapshot.docs.length >= pageSize;
      } catch (queryError) {
        print('[ActualiteProvider] Firestore query with index failed, using fallback: $queryError');
        // Fallback: Query all published actualites and sort/paginate in memory
        final fallbackQuery = await _firestore
            .collection('blogPosts')
            .where('type', isEqualTo: 'actualité')
            .where('isPublished', isEqualTo: true)
            .get();

        final allValid = fallbackQuery.docs
            .where((doc) => doc.data()['status'] != 'DELETED')
            .map((doc) => BlogPost.fromFirestore(doc))
            .where((post) => post.actualiteCategory == mappedCategory)
            .toList();

        // Sort newest first
        allValid.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        state.items = allValid.take(pageSize).toList();
        state.hasMore = allValid.length > pageSize;
        if (state.items.isNotEmpty && fallbackQuery.docs.isNotEmpty) {
          // Find matching document for last item if possible
          final lastItem = state.items.last;
          state.lastDocument = fallbackQuery.docs.firstWhere(
            (d) => d.id == lastItem.id,
            orElse: () => fallbackQuery.docs.last,
          );
        }
      }
    } catch (e) {
      print('[ActualiteProvider] Error loading category $category: $e');
      state.error = e.toString();
    } finally {
      state.isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreActualites(String category) async {
    final state = _getOrCreateState(category);
    if (state.isLoadingMore || !state.hasMore || state.isLoading) {
      return;
    }

    state.isLoadingMore = true;
    notifyListeners();

    try {
      final mappedCategory = _categoryMappings[category] ?? category;

      if (state.lastDocument != null) {
        try {
          final query = _firestore
              .collection('blogPosts')
              .where('type', isEqualTo: 'actualité')
              .where('isPublished', isEqualTo: true)
              .where('actualiteCategory', isEqualTo: mappedCategory)
              .orderBy('createdAt', descending: true)
              .startAfterDocument(state.lastDocument!)
              .limit(pageSize);

          final snapshot = await query.get();
          final docs = snapshot.docs.where((doc) {
            final data = doc.data();
            return data['status'] != 'DELETED';
          }).toList();

          final newItems = docs.map((doc) => BlogPost.fromFirestore(doc)).toList();
          state.items.addAll(newItems);
          state.items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (snapshot.docs.isNotEmpty) {
            state.lastDocument = snapshot.docs.last;
          }
          state.hasMore = snapshot.docs.length >= pageSize;
        } catch (queryError) {
          print('[ActualiteProvider] Fallback loadMore for $category: $queryError');
          final fallbackQuery = await _firestore
              .collection('blogPosts')
              .where('type', isEqualTo: 'actualité')
              .where('isPublished', isEqualTo: true)
              .get();

          final allValid = fallbackQuery.docs
              .where((doc) => doc.data()['status'] != 'DELETED')
              .map((doc) => BlogPost.fromFirestore(doc))
              .where((post) => post.actualiteCategory == mappedCategory)
              .toList();

          allValid.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          final currentCount = state.items.length;
          final nextBatch = allValid.skip(currentCount).take(pageSize).toList();
          state.items.addAll(nextBatch);
          state.hasMore = allValid.length > state.items.length;
        }
      } else {
        state.hasMore = false;
      }
    } catch (e) {
      print('[ActualiteProvider] Error loading more for $category: $e');
    } finally {
      state.isLoadingMore = false;
      notifyListeners();
    }
  }

  List<BlogPost> getActualitesByCategory(String category) {
    final state = _categoryStates[category];
    final items = state?.items ?? [];

    // Ensure sorted newest first
    final sortedItems = List<BlogPost>.from(items)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (_searchQuery.isEmpty) {
      return sortedItems;
    }

    return sortedItems.where((actualite) {
      return actualite.title.toLowerCase().contains(_searchQuery) ||
          actualite.content.toLowerCase().contains(_searchQuery) ||
          (actualite.excerpt?.toLowerCase().contains(_searchQuery) ?? false) ||
          (actualite.author?.toLowerCase().contains(_searchQuery) ?? false) ||
          (actualite.actualiteCategory?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();
  }

  void searchActualites(String query) {
    _searchQuery = query.toLowerCase().trim();
    notifyListeners();
  }

  Future<void> refresh() async {
    await loadActualites();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

