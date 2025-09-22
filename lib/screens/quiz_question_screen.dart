import 'dart:async';
import 'package:flutter/material.dart';
import 'package:novopharma/models/quiz.dart';
import 'package:novopharma/screens/quiz_results_screen.dart';
import 'package:novopharma/services/quiz_service.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/theme.dart';

class QuizQuestionScreen extends StatefulWidget {
  final Quiz quiz;

  const QuizQuestionScreen({super.key, required this.quiz});

  @override
  State<QuizQuestionScreen> createState() => _QuizQuestionScreenState();
}

class _QuizQuestionScreenState extends State<QuizQuestionScreen> with TickerProviderStateMixin {
  late PageController _pageController;
  Timer? _questionTimer;
  int _questionTimeLeft = 0;
  final Map<int, List<int>> _selectedAnswers = {};
  int _currentPage = 0;

  late AnimationController _timerAnimationController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _timerAnimationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.quiz.questions.isNotEmpty ? widget.quiz.questions[0].timeLimitSeconds : 1),
    );
    _startQuestionTimer();
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _pageController.dispose();
    _timerAnimationController.dispose();
    super.dispose();
  }

  void _startQuestionTimer() {
    _questionTimer?.cancel();
    final question = widget.quiz.questions[_currentPage];
    _questionTimeLeft = question.timeLimitSeconds;

    _timerAnimationController.duration = Duration(seconds: _questionTimeLeft);
    _timerAnimationController.reverse(from: 1.0);

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
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _submitQuiz();
    }
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    _startQuestionTimer();
  }

  void _submitQuiz() async {
    _questionTimer?.cancel();
    final userId = Provider.of<AuthProvider>(context, listen: false).firebaseUser!.uid;
    int correctAnswers = 0;
    for (int i = 0; i < widget.quiz.questions.length; i++) {
      final question = widget.quiz.questions[i];
      final selected = _selectedAnswers[i] ?? [];
      final correct = question.correctAnswers;
      
      selected.sort();
      correct.sort();

      if (const ListEquality().equals(selected, correct)) {
        correctAnswers++;
      }
    }
    final pointsEarned = (correctAnswers / widget.quiz.questions.length * widget.quiz.points).round();
    await QuizService().submitQuiz(userId, widget.quiz.id, correctAnswers, pointsEarned);
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => QuizResultsScreen(
          quiz: widget.quiz,
          selectedAnswers: _selectedAnswers,
          totalQuestions: widget.quiz.questions.length,
          correctAnswers: correctAnswers,
          pointsEarned: pointsEarned,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F8FB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Question ${_currentPage + 1}/${widget.quiz.questions.length}',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: AnimatedBuilder(
                    animation: _timerAnimationController,
                    builder: (context, child) {
                      return CircularProgressIndicator(
                        value: _timerAnimationController.value,
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _questionTimeLeft > 5 ? Colors.green : Colors.red,
                        ),
                      );
                    },
                  ),
                ),
                Text(
                  '$_questionTimeLeft',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: _onPageChanged,
        itemCount: widget.quiz.questions.length,
        itemBuilder: (context, index) {
          final question = widget.quiz.questions[index];
          return _buildQuestionPage(question, index);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _nextPage,
        backgroundColor: LightModeColors.novoPharmaBlue,
        child: const Icon(Icons.arrow_forward, color: Colors.white),
      ),
    );
  }

  Widget _buildQuestionPage(QuizQuestion question, int pageIndex) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.text,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF102132)),
          ),
          const SizedBox(height: 12),
          Text(
            question.multipleAnswersAllowed ? 'Select all that apply' : 'Select one answer',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.builder(
              itemCount: question.options.length,
              itemBuilder: (context, optionIndex) {
                final isSelected = _selectedAnswers[pageIndex]?.contains(optionIndex) ?? false;
                return _AnswerCard(
                  text: question.options[optionIndex],
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      final currentSelection = _selectedAnswers[pageIndex] ?? [];
                      if (question.multipleAnswersAllowed) {
                        if (isSelected) {
                          currentSelection.remove(optionIndex);
                        } else {
                          currentSelection.add(optionIndex);
                        }
                        _selectedAnswers[pageIndex] = currentSelection;
                      } else {
                        _selectedAnswers[pageIndex] = [optionIndex];
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _AnswerCard({required this.text, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected ? LightModeColors.novoPharmaBlue.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? LightModeColors.novoPharmaBlue : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 16),
              AnimatedOpacity(
                opacity: isSelected ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.check_circle, color: LightModeColors.novoPharmaBlue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


