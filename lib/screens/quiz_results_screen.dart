import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:novopharma/models/quiz.dart';
import 'package:novopharma/theme.dart';

class QuizResultsScreen extends StatelessWidget {
  final Quiz quiz;
  final Map<int, List<int>> selectedAnswers;
  final int totalQuestions;
  final int correctAnswers;
  final int pointsEarned;

  const QuizResultsScreen({
    super.key,
    required this.quiz,
    required this.selectedAnswers,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.pointsEarned,
  });

  @override
  Widget build(BuildContext context) {
    final double scorePercentage = totalQuestions > 0
        ? correctAnswers / totalQuestions
        : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text('Quiz Results'),
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          _buildHeader(context, scorePercentage),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Review Your Answers',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(child: _buildAnswerReviewList()),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: () {
            int popCount = 0;
            Navigator.of(context).popUntil((_) => popCount++ >= 2);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: LightModeColors.novoPharmaBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Done',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, double scorePercentage) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Column(
        children: [
          Text(
            scorePercentage > 0.7 ? 'Congratulations!' : 'Good Effort!',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: LightModeColors.dashboardTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: scorePercentage,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    scorePercentage > 0.7 ? Colors.green : Colors.orange,
                  ),
                ),
              ),
              Text(
                '$correctAnswers/$totalQuestions',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'You earned $pointsEarned points!',
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerReviewList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: quiz.questions.length,
      itemBuilder: (context, index) {
        final question = quiz.questions[index];
        final userAnswers = selectedAnswers[index] ?? [];
        final correctAnswers = question.correctAnswers;

        userAnswers.sort();
        correctAnswers.sort();

        final bool isCorrect = const ListEquality().equals(
          userAnswers,
          correctAnswers,
        );

        return _AnswerReviewCard(
          questionNumber: index + 1,
          question: question,
          userAnswers: userAnswers,
          isCorrect: isCorrect,
        );
      },
    );
  }
}

class _AnswerReviewCard extends StatelessWidget {
  final int questionNumber;
  final QuizQuestion question;
  final List<int> userAnswers;
  final bool isCorrect;

  const _AnswerReviewCard({
    required this.questionNumber,
    required this.question,
    required this.userAnswers,
    required this.isCorrect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question $questionNumber: ${question.text}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...List.generate(question.options.length, (index) {
              final isUserAnswer = userAnswers.contains(index);
              final isCorrectAnswer = question.correctAnswers.contains(index);
              return _buildOptionTile(
                text: question.options[index],
                isUserAnswer: isUserAnswer,
                isCorrectAnswer: isCorrectAnswer,
              );
            }),
            if (question.explanation.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildExplanationBox(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required String text,
    required bool isUserAnswer,
    required bool isCorrectAnswer,
  }) {
    IconData icon;
    Color color;
    FontWeight fontWeight = FontWeight.normal;

    if (isCorrectAnswer) {
      icon = Icons.check_circle;
      color = Colors.green;
      fontWeight = FontWeight.bold;
    } else if (isUserAnswer && !isCorrectAnswer) {
      icon = Icons.cancel;
      color = Colors.red;
    } else {
      icon = Icons.radio_button_unchecked;
      color = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontWeight: fontWeight, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplanationBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, color: Colors.blue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              question.explanation,
              style: TextStyle(color: Colors.blue.shade800, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
