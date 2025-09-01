import 'package:flutter/foundation.dart';
import 'package:novopharma/models/goal.dart';
import 'package:novopharma/services/goal_service.dart';

class GoalProvider extends ChangeNotifier {
  final GoalService _goalService = GoalService();
  List<Goal> _goals = [];
  bool _isLoading = false;
  String? _error;

  List<Goal> get goals => _goals;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchGoals() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _goals = await _goalService.getActiveGoals();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
