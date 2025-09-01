import 'package:flutter/foundation.dart';
import 'package:novopharma/models/quiz.dart';
import 'package:novopharma/services/quiz_service.dart';

class QuizProvider extends ChangeNotifier {
  final QuizService _quizService = QuizService();
  Quiz? _weeklyQuiz;
  bool _isLoading = false;
  String? _error;

  Quiz? get weeklyQuiz => _weeklyQuiz;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchWeeklyQuiz() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _weeklyQuiz = await _quizService.getWeeklyQuiz();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
