import 'package:flutter/material.dart';

class QuizResultsScreen extends StatelessWidget {
  final int totalQuestions;
  final int correctAnswers;
  final int pointsEarned;

  const QuizResultsScreen({
    super.key,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.pointsEarned,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Results'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('You got $correctAnswers out of $totalQuestions correct!'),
            const SizedBox(height: 16),
            Text('You earned $pointsEarned points!'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}