import 'package:flutter/material.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/controllers/quiz_provider.dart';
import 'package:novopharma/models/quiz.dart';
import 'package:novopharma/screens/quiz_question_screen.dart';
import 'package:novopharma/theme.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';

class QuizListScreen extends StatefulWidget {
  const QuizListScreen({super.key});

  @override
  State<QuizListScreen> createState() => _QuizListScreenState();
}

class _QuizListScreenState extends State<QuizListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = Provider.of<AuthProvider>(
        context,
        listen: false,
      ).firebaseUser?.uid;
      if (userId != null) {
        Provider.of<QuizProvider>(
          context,
          listen: false,
        ).fetchAllQuizzes(userId);
      }
    });
  }

  void _startQuiz(Quiz quiz) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => QuizQuestionScreen(quiz: quiz)),
    ).then((_) {
      // Refetch quiz attempts when returning from a quiz
      final userId = Provider.of<AuthProvider>(
        context,
        listen: false,
      ).firebaseUser?.uid;
      if (userId != null) {
        Provider.of<QuizProvider>(
          context,
          listen: false,
        ).fetchAllQuizzes(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: Text(
          l10n.availableQuizzes,
          style: const TextStyle(
            color: LightModeColors.dashboardTextPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.1),
        iconTheme: const IconThemeData(
          color: LightModeColors.dashboardTextPrimary,
        ),
      ),
      body: Consumer<QuizProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.quizzes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null) {
            return Center(child: Text('Error: ${provider.error}'));
          }
          if (provider.quizzes.isEmpty) {
            return Center(child: Text(l10n.noQuizzesAvailable));
          }

          return RefreshIndicator(
            onRefresh: () async {
              final userId = Provider.of<AuthProvider>(
                context,
                listen: false,
              ).firebaseUser?.uid;
              if (userId != null) {
                await Provider.of<QuizProvider>(
                  context,
                  listen: false,
                ).fetchAllQuizzes(userId);
              }
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: provider.quizzes.length,
              itemBuilder: (context, index) {
                final quiz = provider.quizzes[index];
                final attempts = provider.userAttempts[quiz.id] ?? 0;
                return _buildQuizCard(quiz, attempts, l10n);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuizCard(Quiz quiz, int attempts, AppLocalizations l10n) {
    final bool canAttempt = attempts < quiz.attemptLimit;
    final String buttonText = canAttempt ? l10n.startQuiz : 'Limit Reached';

    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Opacity(
        opacity: canAttempt ? 1.0 : 0.6,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                quiz.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: LightModeColors.dashboardTextPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(
                    icon: Icons.star_border,
                    text: '${quiz.points} ${l10n.points}',
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  _buildInfoChip(
                    icon: Icons.question_answer_outlined,
                    text: '${quiz.questions.length} ${l10n.questions}',
                    color: Colors.blue,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canAttempt ? () => _startQuiz(quiz) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LightModeColors.novoPharmaBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade400,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    buttonText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Attempts: $attempts/${quiz.attemptLimit}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
