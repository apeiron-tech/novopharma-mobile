import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:novopharma/services/leaderboard_service.dart';

class LeaderboardProvider with ChangeNotifier {
  final LeaderboardService _leaderboardService = LeaderboardService();

  List<Map<String, dynamic>> _leaderboardData = [];
  List<Map<String, dynamic>> get leaderboardData => _leaderboardData;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  DocumentSnapshot? _lastDocument;

  int _totalUsersCount = 0;
  int get totalUsersCount => _totalUsersCount;

  int _currentUserRank = 0;
  int get currentUserRank => _currentUserRank;

  String? _lastUserId;

  LeaderboardProvider();

  Future<void> fetchLeaderboard([String? currentUserId]) async {
    _lastUserId = currentUserId;
    _isLoading = true;
    _isLoadingMore = false;
    _hasMore = true;
    _lastDocument = null;
    _leaderboardData = [];
    notifyListeners();

    final result = await _leaderboardService.getLeaderboardPage(
      currentUserId: currentUserId,
      lastDocument: null,
      pageSize: 100,
      startRank: 0,
    );

    _leaderboardData = result.users;
    _lastDocument = result.lastDocument;
    _hasMore = result.hasMore;
    _totalUsersCount = result.totalUsersCount;
    _currentUserRank = result.currentUserRank;

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMoreUsers([String? currentUserId]) async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    final userIdToUse = currentUserId ?? _lastUserId;
    final result = await _leaderboardService.getLeaderboardPage(
      currentUserId: userIdToUse,
      lastDocument: _lastDocument,
      pageSize: 100,
      startRank: _leaderboardData.length,
    );

    if (result.users.isNotEmpty) {
      _leaderboardData.addAll(result.users);
      _lastDocument = result.lastDocument;
    }
    _hasMore = result.hasMore;

    _isLoadingMore = false;
    notifyListeners();
  }
}

