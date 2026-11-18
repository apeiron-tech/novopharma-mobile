import 'package:flutter/material.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/design/design.dart';
import 'package:novopharma/models/quiz.dart';
import 'package:novopharma/services/quiz_service.dart';
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
      backgroundColor: AppColors.canvas,
      appBar: InkAppBar(
        title: "Bonnes réponses du quiz",
        leading: GlassIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onTap: () => Navigator.of(context).pop(),
        ),
      ),
      body: AppBackground(child: SizedBox.expand(child: _buildBody())),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CapsuleLoader());
    }

    if (_errorMessage != null || _quiz == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TintIcon(
                icon: Icons.error_outline_rounded,
                tone: Tone.coral,
                size: 72,
              ),
              const SizedBox(height: 18),
              Text(
                _errorMessage ?? "Impossible de charger le quiz.",
                textAlign: TextAlign.center,
                style: AppText.body(size: 15.5, color: AppColors.textMuted),
              ),
              const SizedBox(height: 22),
              PrimaryButton(
                label: "Réessayer",
                icon: Icons.refresh_rounded,
                onPressed: _loadData,
                expand: false,
                height: 50,
              ),
            ],
          ),
        ),
      );
    }

    final quiz = _quiz!;
    final userAnswersMap = _parseUserAnswers(_lastAttempt?['selectedAnswers']);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.xl,
        AppSpace.lg,
        AppSpace.lg + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Entrance(child: _buildQuizSummaryHeader(quiz)),
        const SizedBox(height: 16),
        ...List.generate(quiz.questions.length, (index) {
          final question = quiz.questions[index];
          final userAnswers = userAnswersMap[index] ?? [];
          final card = _buildQuestionCard(index + 1, question, userAnswers);
          // Only the first screenful arrives in sequence.
          return index < 3
              ? Entrance.staggered(index: index + 1, child: card)
              : card;
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

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BlisterIcon(
                icon: Icons.assignment_turned_in_rounded,
                size: 50,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quiz.title,
                      style: AppText.display(size: 20, height: 1.15),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.ink.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.lock_outline_rounded,
                                size: 13,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "Quiz Clôturé",
                                style: AppText.label(
                                  size: 12,
                                  weight: FontWeight.w700,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          "${quiz.questions.length} questions",
                          style: AppText.label(size: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasAttempt) ...[
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Votre performance :",
                        style: AppText.label(size: 13),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Score: $score / ${quiz.questions.length}",
                          style: AppText.display(size: 26),
                        ),
                      ),
                    ],
                  ),
                ),
                if (pointsEarned > 0) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppGradients.amber,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 17,
                          color: AppColors.ink,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "+$pointsEarned pts",
                          style: AppText.display(
                            size: 15,
                            color: AppColors.ink,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionCard(int questionNumber, QuizQuestion question, List<int> userAnswers) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SoftCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: const BoxConstraints(minWidth: 38),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppGradients.indigo,
                    borderRadius: BorderRadius.circular(AppRadii.xs),
                  ),
                  child: Text(
                    "Q$questionNumber",
                    style: AppText.display(
                      size: 13.5,
                      color: Colors.white,
                      letterSpacing: 0,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      question.text,
                      style: AppText.display(size: 17, height: 1.22),
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
              const SizedBox(height: 8),
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
    Color? bgColor;
    Color borderColor = AppColors.lineStrong;
    Color textColor = AppColors.text;
    FontWeight fontWeight = FontWeight.w500;
    Widget? note;
    Widget trailing;

    if (isCorrect) {
      bgColor = AppColors.mintTint;
      borderColor = AppColors.mint;
      fontWeight = FontWeight.w700;
      if (isUserChoice) {
        note = _buildChoiceNote("Votre réponse", Tone.mint);
      }
      trailing = const Icon(
        Icons.check_circle_rounded,
        color: AppColors.mintDeep,
        size: 22,
      );
    } else if (isUserChoice && !isCorrect) {
      bgColor = AppColors.coralTint;
      borderColor = AppColors.coral;
      fontWeight = FontWeight.w600;
      note = _buildChoiceNote("Votre choix (incorrect)", Tone.coral);
      trailing = const Icon(
        Icons.cancel_rounded,
        color: AppColors.coralDeep,
        size: 22,
      );
    } else {
      textColor = AppColors.textMuted;
      trailing = const Icon(
        Icons.radio_button_unchecked_rounded,
        color: AppColors.textFaint,
        size: 20,
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: borderColor, width: isCorrect ? 1.6 : 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: AppText.body(
                    size: 14.5,
                    weight: fontWeight,
                    color: textColor,
                    height: 1.3,
                  ),
                ),
                if (note != null) ...[const SizedBox(height: 8), note],
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing,
        ],
      ),
    );
  }

  /// Whose answer this was, on a white chip so it reads on the tinted row.
  Widget _buildChoiceNote(String label, Tone tone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: AppText.label(
          size: 11.5,
          weight: FontWeight.w700,
          color: tone.deep,
        ),
      ),
    );
  }

  Widget _buildExplanationBox(String explanation) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.indigoTint,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_rounded,
            color: AppColors.indigo,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Explication :",
                  style: AppText.label(
                    size: 13,
                    weight: FontWeight.w700,
                    color: AppColors.indigoDeep,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  explanation,
                  style: AppText.body(
                    size: 14,
                    color: AppColors.textMuted,
                    height: 1.45,
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
