import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:novopharma/design/design.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';
import 'package:novopharma/models/quiz.dart';

class QuizResultsScreen extends StatefulWidget {
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
  State<QuizResultsScreen> createState() => _QuizResultsScreenState();
}

class _QuizResultsScreenState extends State<QuizResultsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bool hasWon =
          widget.correctAnswers >= widget.quiz.effectiveMinCorrectAnswers;
      if (hasWon && widget.totalQuestions > 0) {
        // The earned win: capsules rain over the congratulation dialog.
        celebrate(context);
        showDialog(
          context: context,
          barrierDismissible: true,
          barrierColor: AppColors.ink.withValues(alpha: 0.5),
          builder: (context) => const _CongratulationDialog(),
        );
      } else {
        showDialog(
          context: context,
          barrierDismissible: true,
          barrierColor: AppColors.ink.withValues(alpha: 0.5),
          builder: (context) => const _SorryDialog(),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double scorePercentage = widget.totalQuestions > 0
        ? widget.correctAnswers / widget.totalQuestions
        : 0;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      extendBody: true,
      // The page is one scroll: the score on ink, then what there is to
      // review. It slides under the frosted bar that holds the way out.
      body: AppBackground(
        child: Builder(
          builder: (context) => CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildHeader(context, scorePercentage),
              ),
              if (widget.quiz.isAvailable)
                _buildHiddenReviewNotice(context)
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.page,
                      24,
                      AppSpace.page,
                      12,
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.reviewYourAnswers,
                      style: AppText.display(size: 20),
                    ),
                  ),
                ),
                _buildAnswerReviewList(),
              ],
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.paddingOf(context).bottom + 20,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: GlassBottomBar(
        child: PrimaryButton(
          label: AppLocalizations.of(context)!.done,
          onPressed: () {
            int popCount = 0;
            Navigator.of(context).popUntil((_) => popCount++ >= 2);
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, double scorePercentage) {
    final bool hasWon =
        widget.correctAnswers >= widget.quiz.effectiveMinCorrectAnswers;
    final Tone tone = hasWon ? Tone.mint : Tone.coral;
    return InkHero(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.page,
        AppSpace.lg,
        AppSpace.page,
        AppSpace.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Entrance(
            offset: const Offset(0, -12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.quizResults,
                        style: AppText.label(
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hasWon
                            ? AppLocalizations.of(context)!.congratulations
                            : AppLocalizations.of(context)!.goodEffort,
                        style: AppText.display(size: 28, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                BlisterIcon(
                  icon: hasWon
                      ? Icons.emoji_events_rounded
                      : Icons.sentiment_dissatisfied_rounded,
                  tone: tone,
                  size: 56,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Entrance(
            delay: const Duration(milliseconds: 120),
            scaleFrom: 0.94,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  CountUp(
                    value: widget.correctAnswers,
                    style: AppText.display(
                      size: 108,
                      weight: FontWeight.w800,
                      color: hasWon ? AppColors.mintBright : Colors.white,
                      height: 1,
                    ),
                  ),
                  Text(
                    '/${widget.totalQuestions}',
                    style: AppText.display(
                      size: 42,
                      color: Colors.white.withValues(alpha: 0.7),
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Entrance(
            delay: const Duration(milliseconds: 200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: CapsuleProgress(
                    value: scorePercentage,
                    tone: tone,
                    trackColor: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                const SizedBox(height: 18),
                _PointsPill(
                  label: AppLocalizations.of(
                    context,
                  )!.youEarnedPoints(widget.pointsEarned),
                  earned: widget.pointsEarned > 0,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHiddenReviewNotice(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.page, 22, AppSpace.page, 0),
        child: Entrance(
          delay: const Duration(milliseconds: 280),
          child: SoftCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BlisterIcon(icon: Icons.lock_clock_rounded, size: 56),
                const SizedBox(height: 16),
                Text(
                  "Corrections masquées",
                  style: AppText.display(size: 21),
                ),
                const SizedBox(height: 8),
                Text(
                  "Afin de garantir l'équité entre tous les participants, les bonnes réponses et les corrections détaillées seront disponibles une fois le quiz clôturé.",
                  style: AppText.body(
                    size: 14.5,
                    color: AppColors.textMuted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.amberTint,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notifications_active_rounded,
                        color: AppColors.amberDeep,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Vous recevrez une notification automatique pour découvrir les réponses correctes !",
                          style: AppText.body(
                            size: 13,
                            weight: FontWeight.w600,
                            color: AppColors.text,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerReviewList() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.builder(
        itemCount: widget.quiz.questions.length,
        itemBuilder: (context, index) {
          final question = widget.quiz.questions[index];
          final userAnswers = widget.selectedAnswers[index] ?? [];
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
      ),
    );
  }
}

/// What the quiz paid: a glowing amber pill when points were earned, a
/// quiet glass one when they were not.
class _PointsPill extends StatelessWidget {
  final String label;
  final bool earned;

  const _PointsPill({required this.label, required this.earned});

  @override
  Widget build(BuildContext context) {
    final Color foreground = earned ? AppColors.ink : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: earned ? AppGradients.amber : null,
        color: earned ? null : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(
          color: Colors.white.withValues(alpha: earned ? 0.4 : 0.2),
        ),
        boxShadow: earned
            ? AppShadows.glow(AppColors.amber, strength: 0.3)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: 20,
            color: earned ? AppColors.ink : AppColors.amber,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: AppText.display(size: 16, color: foreground, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

class _CongratulationDialog extends StatefulWidget {
  const _CongratulationDialog();

  @override
  State<_CongratulationDialog> createState() => _CongratulationDialogState();
}

class _CongratulationDialogState extends State<_CongratulationDialog> {
  Timer? _countdownTimer;
  int _secondsLeft = 10;
  final int _totalSeconds = 10;

  @override
  void initState() {
    super.initState();

    // Countdown and dismiss timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 1) {
          _secondsLeft--;
        } else {
          _countdownTimer?.cancel();
          Navigator.of(context).pop();
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ResultDialog(
      // Close X button
      onClose: () => Navigator.of(context).pop(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 6),
          // Trophy
          Center(
            child: Sheen(
              borderRadius: BorderRadius.circular(48),
              child: const BlisterIcon(
                icon: Icons.emoji_events_rounded,
                tone: Tone.amber,
                size: 96,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Congrats message
          Text(
            "wwwelyé vous gagné le quiz",
            textAlign: TextAlign.center,
            style: AppText.display(size: 25, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            "Bravo pour votre sans-faute !",
            textAlign: TextAlign.center,
            style: AppText.body(
              size: 15,
              color: Colors.white.withValues(alpha: 0.84),
            ),
          ),
          const SizedBox(height: 22),
          // Countdown timer badge
          Center(
            child: _CountdownPill(label: "Fermeture dans $_secondsLeft s"),
          ),
          const SizedBox(height: 12),
          // Countdown progress
          CapsuleProgress(
            value: _secondsLeft / _totalSeconds,
            tone: Tone.amber,
            trackColor: Colors.white.withValues(alpha: 0.14),
            height: 6,
          ),
          const SizedBox(height: 22),
          // Done Button
          PrimaryButton.mint(
            label: "Super !",
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _SorryDialog extends StatefulWidget {
  const _SorryDialog();

  @override
  State<_SorryDialog> createState() => _SorryDialogState();
}

class _SorryDialogState extends State<_SorryDialog> {
  Timer? _countdownTimer;
  int _secondsLeft = 10;
  final int _totalSeconds = 10;

  @override
  void initState() {
    super.initState();

    // Countdown and dismiss timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 1) {
          _secondsLeft--;
        } else {
          _countdownTimer?.cancel();
          Navigator.of(context).pop();
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ResultDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sorry Icon
          const Center(
            child: BlisterIcon(
              icon: Icons.sentiment_very_dissatisfied_rounded,
              tone: Tone.coral,
              size: 88,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Dommage",
            textAlign: TextAlign.center,
            style: AppText.display(size: 27, color: AppColors.coral),
          ),
          const SizedBox(height: 8),
          Text(
            "Vous n'avez pas gagné cette fois-ci",
            textAlign: TextAlign.center,
            style: AppText.body(
              size: 15,
              color: Colors.white.withValues(alpha: 0.84),
            ),
          ),
          const SizedBox(height: 22),
          // Countdown timer badge
          Center(
            child: _CountdownPill(label: "Fermeture dans $_secondsLeft s"),
          ),
          const SizedBox(height: 12),
          // Countdown progress
          CapsuleProgress(
            value: _secondsLeft / _totalSeconds,
            tone: Tone.coral,
            trackColor: Colors.white.withValues(alpha: 0.14),
            height: 6,
          ),
          const SizedBox(height: 22),
          // Done Button
          SecondaryButton(
            label: "Fermer",
            onDark: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// The shell both result dialogs share: a pane of smoked glass that rises
/// into place, so white text stays readable whether it lands over the ink
/// hero or the pastel canvas.
class _ResultDialog extends StatelessWidget {
  final Widget child;
  final VoidCallback? onClose;

  const _ResultDialog({required this.child, this.onClose});

  @override
  Widget build(BuildContext context) {
    return Entrance(
      scaleFrom: 0.92,
      offset: const Offset(0, 18),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Glass(
          style: GlassStyle.smoked,
          blur: Glass.frost,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
                child: child,
              ),
              if (onClose != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GlassIconButton(
                    icon: Icons.close_rounded,
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onTap: onClose,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountdownPill extends StatelessWidget {
  final String label;

  const _CountdownPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 16,
            color: Colors.white.withValues(alpha: 0.86),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: AppText.label(size: 13, color: Colors.white),
            ),
          ),
        ],
      ),
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
                Expanded(
                  child: Text(
                    AppLocalizations.of(
                      context,
                    )!.questionNumber(questionNumber, question.text),
                    style: AppText.display(size: 17, height: 1.22),
                  ),
                ),
                const SizedBox(width: 12),
                TintIcon(
                  icon: isCorrect ? Icons.check_rounded : Icons.close_rounded,
                  tone: isCorrect ? Tone.mint : Tone.coral,
                  size: 32,
                ),
              ],
            ),
            if (userAnswers.isEmpty) ...[
              const SizedBox(height: 10),
              TonePill(
                label: AppLocalizations.of(context)!.noAnswerSelected,
                tone: Tone.coral,
                icon: Icons.remove_circle_outline_rounded,
              ),
            ],
            const SizedBox(height: 14),
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
              const SizedBox(height: 8),
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
    Color textColor = AppColors.textMuted;
    Color? fill;
    FontWeight fontWeight = FontWeight.w500;

    if (isCorrectAnswer) {
      icon = Icons.check_circle_rounded;
      color = AppColors.mintDeep;
      textColor = AppColors.text;
      fill = AppColors.mintTint;
      fontWeight = FontWeight.w700;
    } else if (isUserAnswer && !isCorrectAnswer) {
      icon = Icons.cancel_rounded;
      color = AppColors.coralDeep;
      textColor = AppColors.text;
      fill = AppColors.coralTint;
      fontWeight = FontWeight.w600;
    } else {
      icon = Icons.radio_button_unchecked_rounded;
      color = AppColors.textFaint;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppText.body(
                size: 14.5,
                weight: fontWeight,
                color: textColor,
                height: 1.3,
              ),
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
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              question.explanation,
              style: AppText.body(
                size: 14,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
