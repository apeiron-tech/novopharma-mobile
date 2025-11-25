import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:novopharma/models/blog_post.dart';
import 'package:novopharma/services/blog_post_service.dart';

class FormationProvider with ChangeNotifier {
  final BlogPostService _blogPostService = BlogPostService();

  List<BlogPost> _formations = [];
  List<BlogPost> _allFormations = [];
  bool _isLoading = true;
  String? _error;
  StreamSubscription<List<BlogPost>>? _formationsSubscription;
  String _selectedFilter = 'all'; // all, active, tags

  // Getters
  List<BlogPost> get formations => _formations;
  List<BlogPost> get allFormations => _allFormations;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get selectedFilter => _selectedFilter;

  // Get unique tags from all formations
  List<String> get availableTags {
    final Set<String> tagSet = {};
    for (final formation in _allFormations) {
      tagSet.addAll(formation.tags);
    }
    return tagSet.toList()..sort();
  }

  // Get active formations only
  List<BlogPost> get activeFormations {
    return _allFormations.where((formation) => formation.isActive).toList();
  }

  FormationProvider() {
    _initialize();
  }

  void _initialize() {
    _subscribeToFormations();
  }

  void _subscribeToFormations() {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _formationsSubscription?.cancel();
    _formationsSubscription = _blogPostService.getFormationsStream().listen(
      (formations) {
        _allFormations = formations;
        _applyCurrentFilter();
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        _error = 'Failed to load formations: ${error.toString()}';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void _applyCurrentFilter() {
    switch (_selectedFilter) {
      case 'active':
        _formations = activeFormations;
        break;
      case 'all':
      default:
        _formations = _allFormations;
        break;
    }
  }

  // Filter formations
  void filterByStatus(String filter) {
    _selectedFilter = filter;
    _applyCurrentFilter();
    notifyListeners();
  }

  void filterByTag(String tag) {
    _formations = _allFormations
        .where((formation) => formation.tags.contains(tag))
        .toList();
    _selectedFilter = 'tag:$tag';
    notifyListeners();
  }

  void showAllFormations() {
    _formations = _allFormations;
    _selectedFilter = 'all';
    notifyListeners();
  }

  void showActiveFormations() {
    _formations = activeFormations;
    _selectedFilter = 'active';
    notifyListeners();
  }

  // Search functionality
  Future<void> searchFormations(String query) async {
    if (query.trim().isEmpty) {
      _applyCurrentFilter();
      notifyListeners();
      return;
    }

    try {
      final searchResults = await _blogPostService.searchFormations(query);
      _formations = searchResults;
      _selectedFilter = 'search:$query';
      notifyListeners();
    } catch (e) {
      _error = 'Search failed: ${e.toString()}';
      notifyListeners();
    }
  }

  // Get formation by ID
  BlogPost? getFormationById(String id) {
    try {
      return _allFormations.firstWhere((formation) => formation.id == id);
    } catch (e) {
      return null;
    }
  }

  // Get formation by slug
  BlogPost? getFormationBySlug(String slug) {
    try {
      return _allFormations.firstWhere((formation) => formation.slug == slug);
    } catch (e) {
      return null;
    }
  }

  // Refresh data
  Future<void> refresh() async {
    _subscribeToFormations();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _formationsSubscription?.cancel();
    super.dispose();
  }

  // Helper methods for UI
  bool get hasFormations => _formations.isNotEmpty;
  bool get hasError => _error != null;
  int get formationsCount => _formations.length;

  // Get formations grouped by status
  Map<String, List<BlogPost>> get formationsByStatus {
    final Map<String, List<BlogPost>> grouped = {
      'active': [],
      'upcoming': [],
      'past': [],
    };

    final now = DateTime.now();

    for (final formation in _allFormations) {
      if (formation.startDate != null && formation.endDate != null) {
        if (now.isBefore(formation.startDate!)) {
          grouped['upcoming']!.add(formation);
        } else if (now.isAfter(formation.endDate!)) {
          grouped['past']!.add(formation);
        } else {
          grouped['active']!.add(formation);
        }
      } else {
        // If no dates specified, consider as active
        grouped['active']!.add(formation);
      }
    }

    return grouped;
  }

  // Get recent formations (last 30 days)
  List<BlogPost> get recentFormations {
    final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
    return _allFormations
        .where((formation) => formation.publishedAt.isAfter(cutoffDate))
        .toList();
  }
}
