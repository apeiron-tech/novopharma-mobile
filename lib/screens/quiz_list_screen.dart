import 'package:flutter/material.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/controllers/quiz_provider.dart';
import 'package:novopharma/design/design.dart';
import 'package:novopharma/models/quiz.dart';
import 'package:novopharma/screens/quiz_question_screen.dart';
import 'package:novopharma/screens/quiz_correction_screen.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';

class QuizListScreen extends StatefulWidget {
  const QuizListScreen({super.key});

  @override
  State<QuizListScreen> createState() => _QuizListScreenState();
}

class _QuizListScreenState extends State<QuizListScreen> {
  /// When the list first appeared. Cards built while it is arriving get a
  /// staggered entrance; later builds (scroll, refresh) do not replay it.
  DateTime? _listShownAt;

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

  Widget _arriving(int index, Widget child) {
    _listShownAt ??= DateTime.now();
    final arriving =
        index < 8 &&
        DateTime.now().difference(_listShownAt!) <
            const Duration(milliseconds: 1200);
    return arriving ? Entrance.staggered(index: index, child: child) : child;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: InkAppBar(title: l10n.availableQuizzes),
      body: AppBackground(
        child: SizedBox.expand(
          child: Consumer<QuizProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading && provider.quizzes.isEmpty) {
                return const SkeletonList(count: 4, itemHeight: 176);
              }
              if (provider.error != null) {
                return _buildError('Error: ${provider.error}');
              }
              if (provider.quizzes.isEmpty) {
                return EmptyState(
                  icon: Icons.quiz_rounded,
                  title: l10n.noQuizzesAvailable,
                );
              }

              return RefreshIndicator(
                color: AppColors.indigo,
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
                  padding: EdgeInsets.fromLTRB(
                    AppSpace.lg,
                    AppSpace.xl,
                    AppSpace.lg,
                    AppSpace.xl + MediaQuery.paddingOf(context).bottom,
                  ),
                  itemCount: provider.quizzes.length,
                  itemBuilder: (context, index) {
                    final quiz = provider.quizzes[index];
                    final attempts = provider.userAttempts[quiz.id] ?? 0;
                    return _arriving(
                      index,
                      _buildQuizCard(quiz, attempts, l10n),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
              message,
              textAlign: TextAlign.center,
              style: AppText.body(size: 15, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizCard(Quiz quiz, int attempts, AppLocalizations l10n) {
    final bool isClosed = !quiz.isAvailable;
    final bool canAttempt = !isClosed && attempts < quiz.attemptLimit;

    String buttonText;
    VoidCallback? onButtonPressed;

    if (isClosed) {
      if (attempts > 0) {
        buttonText = "Voir les bonnes réponses";
        onButtonPressed = () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  QuizCorrectionScreen(quizId: quiz.id, quiz: quiz),
            ),
          );
        };
      } else {
        buttonText = "Quiz clôturé";
        onButtonPressed = null;
      }
    } else {
      buttonText = canAttempt ? l10n.startQuiz : 'Limite atteinte';
      onButtonPressed = canAttempt ? () => _startQuiz(quiz) : null;
    }

    // An open quiz leads with a glowing start pill, a closed one offers its
    // corrections more quietly, and a locked one only states why.
    final Widget action;
    if (onButtonPressed == null) {
      action = _buildLockedState(buttonText);
    } else if (isClosed) {
      action = SecondaryButton(
        label: buttonText,
        icon: Icons.assignment_turned_in_rounded,
        tone: Tone.mint,
        onPressed: onButtonPressed,
      );
    } else {
      action = PrimaryButton(
        label: buttonText,
        icon: Icons.play_arrow_rounded,
        onPressed: onButtonPressed,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Opacity(
        opacity: (canAttempt || (isClosed && attempts > 0)) ? 1.0 : 0.6,
        child: SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (canAttempt)
                    const BlisterIcon(icon: Icons.quiz_rounded, size: 48)
                  else
                    const TintIcon(icon: Icons.quiz_rounded, size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        quiz.title,
                        style: AppText.display(size: 19, height: 1.15),
                      ),
                    ),
                  ),
                  if (isClosed) ...[
                    const SizedBox(width: 8),
                    _buildNeutralPill(
                      icon: Icons.lock_outline_rounded,
                      child: Text(
                        "Clôturé",
                        style: AppText.label(
                          size: 12,
                          weight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TonePill(
                    icon: Icons.star_rounded,
                    label: '${formatPoints(quiz.points)} ${l10n.points}',
                    tone: Tone.amber,
                  ),
                  TonePill(
                    icon: Icons.question_answer_rounded,
                    label: '${quiz.questions.length} ${l10n.questions}',
                  ),
                  _buildNeutralPill(
                    icon: Icons.replay_rounded,
                    child: Text.rich(
                      TextSpan(
                        style: AppText.label(
                          size: 12,
                          weight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                        children: [
                          const TextSpan(text: 'Tentatives : '),
                          TextSpan(
                            text: '$attempts/${quiz.attemptLimit}',
                            style: AppText.display(
                              size: 12.5,
                              color: AppColors.text,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              action,
            ],
          ),
        ),
      ),
    );
  }

  /// Why a quiz cannot be started, stated instead of offered as a button.
  Widget _buildLockedState(String text) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(
                size: 15,
                weight: FontWeight.w700,
                color: AppColors.textMuted,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeutralPill({required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 4),
          child,
        ],
      ),
    );
  }
}
