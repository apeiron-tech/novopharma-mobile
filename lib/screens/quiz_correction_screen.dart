import 'package:flutter/material.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/models/quiz.dart';
import 'package:novopharma/services/quiz_service.dart';
import 'package:novopharma/theme.dart';
import 'package:provider/provider.dart';

class QuizCorrectionScreen extends StatefulWidget {
  final String quizId;
  final Quiz? quiz;

  const QuizCorrectionScreen({
    super.key,
    required this.quizId,
    this.quiz,
  });

  @override
  State<QuizCorrectionScreen> createState() => _QuizCorrectionScreenState();
}

class _QuizCorrectionScreenState extends State<QuizCorrectionScreen> {
  final QuizService _quizService = QuizService();
  Quiz? _quiz;
  Map<String, dynamic>? _lastAttempt;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final quiz = widget.quiz ?? await _quizService.getQuizById(widget.quizId);
      if (quiz == null) {
        setState(() {
          _errorMessage = "Quiz introuvable ou indisponible.";
          _isLoading = false;
        });
        return;
      }

      final userId =
          Provider.of<AuthProvider>(context, listen: false).firebaseUser?.uid;
      Map<String, dynamic>? attempt;
      if (userId != null) {
        attempt = await _quizService.getLastUserAttempt(userId, quiz.id);
      }

      setState(() {
        _quiz = quiz;
        _lastAttempt = attempt;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Erreur lors du chargement des réponses: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.08),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: LightModeColors.dashboardTextPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Bonnes réponses du quiz",
          style: TextStyle(
            color: LightModeColors.dashboardTextPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null || _quiz == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 54, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? "Impossible de charger le quiz.",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: LightModeColors.novoPharmaBlue,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Réessayer"),
              ),
            ],
          ),
        ),
      );
    }

    final quiz = _quiz!;
    final userAnswersMap = _parseUserAnswers(_lastAttempt?['selectedAnswers']);

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildQuizSummaryHeader(quiz),
        const SizedBox(height: 16),
        ...List.generate(quiz.questions.length, (index) {
          final question = quiz.questions[index];
          final userAnswers = userAnswersMap[index] ?? [];
          return _buildQuestionCard(index + 1, question, userAnswers);
        }),
        const SizedBox(height: 24),
      ],
    );
  }

  Map<int, List<int>> _parseUserAnswers(dynamic raw) {
    final Map<int, List<int>> result = {};
    if (raw == null || raw is! Map) return result;

    raw.forEach((key, value) {
      final questionIndex = int.tryParse(key.toString());
      if (questionIndex != null && value is List) {
        result[questionIndex] = value.map((e) => int.tryParse(e.toString()) ?? 0).toList();
      }
    });

    return result;
  }

  Widget _buildQuizSummaryHeader(Quiz quiz) {
    final hasAttempt = _lastAttempt != null;
    final int score = _lastAttempt?['score'] ?? 0;
    final int pointsEarned = _lastAttempt?['pointsEarned'] ?? 0;

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: LightModeColors.novoPharmaBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.assignment_turned_in_rounded,
                    color: LightModeColors.novoPharmaBlue,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
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
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              "Quiz Clôturé",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "${quiz.questions.length} questions",
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (hasAttempt) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Votre performance :",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          "Score: $score / ${quiz.questions.length}",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ),
                      if (pointsEarned > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Text(
                            "+$pointsEarned pts",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int questionNumber, QuizQuestion question, List<int> userAnswers) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.06),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: LightModeColors.novoPharmaBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Q$questionNumber",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    question.text,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF102132),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(question.options.length, (optIndex) {
              final isCorrect = question.correctAnswers.contains(optIndex);
              final isUserChoice = userAnswers.contains(optIndex);
              return _buildOptionTile(
                text: question.options[optIndex],
                isCorrect: isCorrect,
                isUserChoice: isUserChoice,
              );
            }),
            if (question.explanation.isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildExplanationBox(question.explanation),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required String text,
    required bool isCorrect,
    required bool isUserChoice,
  }) {
    Color bgColor = Colors.white;
    Color borderColor = Colors.grey.shade200;
    Color textColor = const Color(0xFF102132);
    FontWeight fontWeight = FontWeight.normal;
    Widget? trailing;

    if (isCorrect) {
      bgColor = Colors.green.shade50;
      borderColor = Colors.green.shade400;
      textColor = Colors.green.shade900;
      fontWeight = FontWeight.bold;
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isUserChoice) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "Votre réponse",
                style: TextStyle(
                  color: Colors.green.shade900,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
        ],
      );
    } else if (isUserChoice && !isCorrect) {
      bgColor = Colors.red.shade50;
      borderColor = Colors.red.shade300;
      textColor = Colors.red.shade900;
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              "Votre choix (incorrect)",
              style: TextStyle(
                color: Colors.red.shade900,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.cancel_rounded, color: Colors.red, size: 22),
        ],
      );
    } else {
      trailing = Icon(Icons.radio_button_unchecked, color: Colors.grey.shade400, size: 20);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isCorrect ? 1.8 : 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: fontWeight,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildExplanationBox(String explanation) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_rounded, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Explication :",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  explanation,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue.shade900,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

