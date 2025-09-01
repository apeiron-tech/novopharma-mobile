import 'dart:async';
import 'package:flutter/material.dart';
import 'package:novopharma/models/quiz.dart';
import 'package:novopharma/screens/quiz_results_screen.dart';
import 'package:novopharma/services/quiz_service.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/controllers/auth_provider.dart';

class QuizQuestionScreen extends StatefulWidget {
  final Quiz quiz;

  const QuizQuestionScreen({super.key, required this.quiz});

  @override
  State<QuizQuestionScreen> createState() => _QuizQuestionScreenState();
}

class _QuizQuestionScreenState extends State<QuizQuestionScreen> {
  int _currentPage = 0;
  Timer? _questionTimer;
  int _questionTimeLeft = 0;
  final Map<int, List<int>> _selectedAnswers = {};

  @override
  void initState() {
    super.initState();
    _startQuestionTimer();
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    super.dispose();
  }

  void _startQuestionTimer() {
    _questionTimeLeft = widget.quiz.questions[_currentPage].timeLimitSeconds;
    _questionTimer?.cancel();
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_questionTimeLeft > 0) {
        setState(() {
          _questionTimeLeft--;
        });
      } else {
        _nextPage();
      }
    });
  }

  void _nextPage() {
    if (_currentPage < widget.quiz.questions.length - 1) {
      setState(() {
        _currentPage++;
      });
      _startQuestionTimer();
    } else {
      _submitQuiz();
    }
  }

  void _submitQuiz() async {
    _questionTimer?.cancel();
    final userId = Provider.of<AuthProvider>(context, listen: false).firebaseUser!.uid;
    int correctAnswers = 0;
    for (int i = 0; i < widget.quiz.questions.length; i++) {
      final question = widget.quiz.questions[i];
      final selected = _selectedAnswers[i] ?? [];
      final correct = question.correctAnswers;
      if (selected.length == correct.length && selected.every((answer) => correct.contains(answer))) {
        correctAnswers++;
      }
    }
    final pointsEarned = (correctAnswers / widget.quiz.questions.length * widget.quiz.points).round();
    await QuizService().submitQuiz(userId, widget.quiz.id, correctAnswers, pointsEarned);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => QuizResultsScreen(
          totalQuestions: widget.quiz.questions.length,
          correctAnswers: correctAnswers,
          pointsEarned: pointsEarned,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.quiz.questions[_currentPage];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quiz.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: LinearProgressIndicator(
            value: (_currentPage + 1) / widget.quiz.questions.length,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Question ${_currentPage + 1} of ${widget.quiz.questions.length}'),
            const SizedBox(height: 16),
            Text('Time left: $_questionTimeLeft'),
            const SizedBox(height: 16),
            Text(question.text, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: question.options.length,
                itemBuilder: (context, index) {
                  final isSelected = _selectedAnswers[_currentPage]?.contains(index) ?? false;
                  return CheckboxListTile(
                    title: Text(question.options[index]),
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (question.multipleAnswersAllowed) {
                          if (isSelected) {
                            _selectedAnswers[_currentPage]!.remove(index);
                          } else {
                            _selectedAnswers[_currentPage] = [..._selectedAnswers[_currentPage] ?? [], index];
                          }
                        } else {
                          _selectedAnswers[_currentPage] = [index];
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _nextPage,
        child: const Icon(Icons.arrow_forward),
      ),
    );
  }
}
