import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:novopharma/models/quiz.dart';
import 'package:novopharma/services/quiz_service.dart';

class QuizState {
  final Quiz quiz;
  int currentQuestionIndex = 0;
  Timer? quizTimer;
  int quizTimeLeft;
  Timer? questionTimer;
  int questionTimeLeft;

  QuizState({
    required this.quiz,
    required this.quizTimeLeft,
    required this.questionTimeLeft,
  });
}

class QuizProvider extends ChangeNotifier {
  final QuizService _quizService = QuizService();
  List<Quiz> _quizzes = [];
  Map<String, int> _userAttempts = {};
  bool _isLoading = false;
  String? _error;

  QuizState? _activeQuizState;

  List<Quiz> get quizzes => _quizzes;
  Map<String, int> get userAttempts => _userAttempts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  QuizState? get activeQuizState => _activeQuizState;

  Future<void> fetchAllQuizzes(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _quizzes = await _quizService.getAllQuizzes();
      _userAttempts = {}; // Reset attempts
      for (final quiz in _quizzes) {
        final attemptCount = await _quizService.getUserAttemptCount(
          userId,
          quiz.id,
        );
        _userAttempts[quiz.id] = attemptCount;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void startQuiz(Quiz quiz, VoidCallback onQuizEnd) {
    _activeQuizState = QuizState(
      quiz: quiz,
      quizTimeLeft: quiz.quizTimeLimitSeconds,
      questionTimeLeft: quiz.questions.isNotEmpty
          ? quiz.questions.first.timeLimitSeconds
          : 0,
    );

    _activeQuizState!.quizTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      if (_activeQuizState!.quizTimeLeft > 0) {
        _activeQuizState!.quizTimeLeft--;
        notifyListeners();
      } else {
        timer.cancel();
        onQuizEnd();
      }
    });

    _startQuestionTimer();
  }

  void _startQuestionTimer() {
    _activeQuizState?.questionTimer?.cancel();
    if (_activeQuizState == null ||
        _activeQuizState!.currentQuestionIndex >=
            _activeQuizState!.quiz.questions.length) {
      return;
    }

    final question = _activeQuizState!
        .quiz
        .questions[_activeQuizState!.currentQuestionIndex];
    _activeQuizState!.questionTimeLeft = question.timeLimitSeconds;
    notifyListeners();

    _activeQuizState!.questionTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (_activeQuizState!.questionTimeLeft > 0) {
          _activeQuizState!.questionTimeLeft--;
          notifyListeners();
        } else {
          nextQuestion();
        }
      },
    );
  }

  void nextQuestion() {
    if (_activeQuizState == null) return;

    if (_activeQuizState!.currentQuestionIndex <
        _activeQuizState!.quiz.questions.length - 1) {
      _activeQuizState!.currentQuestionIndex++;
      _startQuestionTimer();
    } else {
      // Last question, stop timers
      _activeQuizState!.quizTimer?.cancel();
      _activeQuizState!.questionTimer?.cancel();
    }
    notifyListeners();
  }

  void stopQuiz() {
    _activeQuizState?.quizTimer?.cancel();
    _activeQuizState?.questionTimer?.cancel();
    _activeQuizState = null;
  }
}
