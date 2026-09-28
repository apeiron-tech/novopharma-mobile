import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/blog_post.dart';
import '../models/custom_page_model.dart';

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
      // Load initial batch of items for each category
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

  Future<List<BlogPost>> _fetchSharedCustomPages(String mappedCategory) async {
    try {
      final snapshot = await _firestore
          .collection('customPage')
          .where('status', isEqualTo: 'active')
          .where('shareInActualites', isEqualTo: true)
          .where('actualiteCategory', isEqualTo: mappedCategory)
          .get();

      final pages = snapshot.docs
          .where((doc) {
            final data = doc.data();
            return data['status'] != 'DELETED';
          })
          .map((doc) => CustomPageModel.fromFirestore(doc))
          .map((page) => BlogPost.fromCustomPage(page))
          .toList();

      return pages;
    } catch (e) {
      print('[ActualiteProvider] Error fetching shared custom pages for $mappedCategory: $e');
      // Fallback: query active custom pages and filter in memory if composite index is pending
      try {
        final fallbackSnapshot = await _firestore
            .collection('customPage')
            .where('status', isEqualTo: 'active')
            .get();

        return fallbackSnapshot.docs
            .where((doc) {
              final data = doc.data();
              return data['status'] != 'DELETED' &&
                  data['shareInActualites'] == true &&
                  data['actualiteCategory'] == mappedCategory;
            })
            .map((doc) => CustomPageModel.fromFirestore(doc))
            .map((page) => BlogPost.fromCustomPage(page))
            .toList();
      } catch (fallbackError) {
        print('[ActualiteProvider] Fallback custom pages error: $fallbackError');
        return [];
      }
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

      // Fetch shared custom pages in parallel with initial batch of blog posts
      final customPagesFuture = _fetchSharedCustomPages(mappedCategory);

      List<BlogPost> blogPosts = [];
      DocumentSnapshot? lastDoc;
      bool hasMorePosts = false;

      // Try ordered Firestore query for blog posts
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

        blogPosts = docs.map((doc) => BlogPost.fromFirestore(doc)).toList();

        if (snapshot.docs.isNotEmpty) {
          lastDoc = snapshot.docs.last;
        }
        hasMorePosts = snapshot.docs.length >= pageSize;
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

        allValid.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        blogPosts = allValid.take(pageSize).toList();
        hasMorePosts = allValid.length > pageSize;
        if (blogPosts.isNotEmpty && fallbackQuery.docs.isNotEmpty) {
          final lastItem = blogPosts.last;
          lastDoc = fallbackQuery.docs.firstWhere(
            (d) => d.id == lastItem.id,
            orElse: () => fallbackQuery.docs.last,
          );
        }
      }

      final customPages = await customPagesFuture;

      // Combine both blog posts and custom pages, avoiding duplicates by id
      final Map<String, BlogPost> uniqueItems = {};
      for (final post in blogPosts) {
        uniqueItems[post.id] = post;
      }
      for (final page in customPages) {
        uniqueItems[page.id] = page;
      }

      final combined = uniqueItems.values.toList();
      // Ensure strictly sorted newest first
      combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      state.items = combined;
      state.lastDocument = lastDoc;
      state.hasMore = hasMorePosts;
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
          final existingIds = state.items.map((i) => i.id).toSet();
          for (final item in newItems) {
            if (!existingIds.contains(item.id)) {
              state.items.add(item);
            }
          }
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

          final currentBlogCount = state.items.where((i) => !i.isCustomPage).length;
          final nextBatch = allValid.skip(currentBlogCount).take(pageSize).toList();
          final existingIds = state.items.map((i) => i.id).toSet();
          for (final item in nextBatch) {
            if (!existingIds.contains(item.id)) {
              state.items.add(item);
            }
          }
          state.items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          state.hasMore = allValid.length > currentBlogCount + nextBatch.length;
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

