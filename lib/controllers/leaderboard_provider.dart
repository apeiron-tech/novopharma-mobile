import 'package:flutter/material.dart';
import 'package:novopharma/services/leaderboard_service.dart';

class LeaderboardProvider with ChangeNotifier {
  final LeaderboardService _leaderboardService = LeaderboardService();

  List<Map<String, dynamic>> _leaderboardData = [];
  List<Map<String, dynamic>> get leaderboardData => _leaderboardData;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String _selectedPeriod = 'weekly';
  String get selectedPeriod => _selectedPeriod;

  LeaderboardProvider() {
    // Fetch initial data
    fetchLeaderboard(_selectedPeriod);
  }

  Future<void> fetchLeaderboard(String period) async {
    _selectedPeriod = period;
    _isLoading = true;
    notifyListeners();

    _leaderboardData = await _leaderboardService.getLeaderboard(period);
    
    _isLoading = false;
    notifyListeners();
  }
}
