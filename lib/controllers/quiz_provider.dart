import 'package:flutter/foundation.dart';
import 'package:novopharma/models/quiz.dart';
import 'package:novopharma/services/quiz_service.dart';

class QuizProvider extends ChangeNotifier {
  final QuizService _quizService = QuizService();
  List<Quiz> _quizzes = [];
  Map<String, int> _userAttempts = {};
  bool _isLoading = false;
  String? _error;

  List<Quiz> get quizzes => _quizzes;
  Map<String, int> get userAttempts => _userAttempts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchAllQuizzes(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _quizzes = await _quizService.getAllQuizzes();
      _userAttempts = {}; // Reset attempts
      for (final quiz in _quizzes) {
        final attemptCount = await _quizService.getUserAttemptCount(userId, quiz.id);
        _userAttempts[quiz.id] = attemptCount;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

