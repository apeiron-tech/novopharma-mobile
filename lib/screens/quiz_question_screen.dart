import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:novopharma/controllers/quiz_provider.dart';
import 'package:novopharma/design/design.dart';
import 'package:novopharma/models/quiz.dart';
import 'package:novopharma/screens/quiz_results_screen.dart';
import 'package:novopharma/services/quiz_service.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';

class QuizQuestionScreen extends StatefulWidget {
  final Quiz quiz;

  const QuizQuestionScreen({super.key, required this.quiz});

  @override
  State<QuizQuestionScreen> createState() => _QuizQuestionScreenState();
}

class _QuizQuestionScreenState extends State<QuizQuestionScreen> {
  late final PageController _pageController;
  final Map<int, List<int>> _selectedAnswers = {};
  late final QuizProvider _quizProvider;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _quizProvider = Provider.of<QuizProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _quizProvider.startQuiz(
        widget.quiz,
        onQuizEnd: _submitQuiz,
        onQuestionTimerEnd: _nextPage,
      );
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _quizProvider.stopQuiz();
    super.dispose();
  }

  void _nextPage() {
    final state = _quizProvider.activeQuizState;
    if (state == null) return;

    if (state.currentQuestionIndex < widget.quiz.questions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      _quizProvider.nextQuestion(_nextPage);
    } else {
      _submitQuiz();
    }
  }

  void _submitQuiz() async {
    if (!mounted) return;
    _quizProvider.stopQuiz();

    final userId = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).firebaseUser!.uid;
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
    // Only award points if the minimum correct answers threshold is met
    final pointsEarned =
        (correctAnswers >= widget.quiz.effectiveMinCorrectAnswers)
        ? widget.quiz.points
        : 0;
    await QuizService().submitQuiz(
      userId,
      widget.quiz.id,
      correctAnswers,
      pointsEarned,
      selectedAnswers: _selectedAnswers,
    );

    if (mounted) {
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
  }

  Future<void> _handleExitQuiz() async {
    final locale = Localizations.localeOf(context).languageCode;
    final isEn = locale == 'en';
    final title = isEn ? 'Exit Quiz?' : 'Quitter le quiz ?';
    final content = isEn
        ? 'If you exit now, your current progress will be submitted and it will count as an attempt.'
        : 'Si vous quittez maintenant, votre progression actuelle sera soumise et cela comptera comme une tentative.';
    final cancelText = isEn ? 'Cancel' : 'Annuler';
    final exitText = isEn ? 'Exit' : 'Quitter';

    final bool? shouldExit = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.ink.withValues(alpha: 0.5),
      builder: (context) => _SmokedDialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BlisterIcon(
              icon: Icons.logout_rounded,
              tone: Tone.coral,
              size: 52,
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: AppText.display(size: 23, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: AppText.body(
                size: 15,
                color: Colors.white.withValues(alpha: 0.82),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: cancelText,
                    onDark: true,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton.coral(
                    label: exitText,
                    height: 52,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (shouldExit == true && mounted) {
      _submitQuiz();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<QuizProvider>(
      builder: (context, quizProvider, child) {
        final state = quizProvider.activeQuizState;
        if (state == null) {
          return const Scaffold(
            backgroundColor: AppColors.ink,
            body: Stack(
              fit: StackFit.expand,
              children: [
                AuroraBackground(),
                Center(
                  child: CapsuleLoader(
                    left: Colors.white,
                    right: AppColors.mint,
                  ),
                ),
              ],
            ),
          );
        }

        final currentQuestion =
            widget.quiz.questions[state.currentQuestionIndex];
        final questionTimeLeft = state.questionTimeLeft;
        final totalQuestionTime = currentQuestion.timeLimitSeconds;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            await _handleExitQuiz();
          },
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: Scaffold(
              backgroundColor: AppColors.ink,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  const AuroraBackground(),
                  SafeArea(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Entrance(
                              offset: const Offset(0, -12),
                              child: _buildHeader(
                                state,
                                questionTimeLeft,
                                totalQuestionTime,
                              ),
                            ),
                            Expanded(
                              child: PageView.builder(
                                controller: _pageController,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: widget.quiz.questions.length,
                                itemBuilder: (context, index) {
                                  final question = widget.quiz.questions[index];
                                  return _buildQuestionPage(question, index);
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                              child: _AdvanceButton(onTap: _nextPage),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Where you are and how long you have: the way out and the quiz clock,
  /// then the question count over its progress capsule beside the
  /// per-question countdown.
  Widget _buildHeader(QuizState state, int timeLeft, int totalTime) {
    final total = widget.quiz.questions.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GlassIconButton(
                icon: Icons.close_rounded,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onTap: _handleExitQuiz,
              ),
              const Spacer(),
              Glass(
                style: GlassStyle.dark,
                shadow: false,
                height: 44,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.86),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(state.quizTimeLeft ~/ 60).toString().padLeft(2, '0')}:${(state.quizTimeLeft % 60).toString().padLeft(2, '0')}',
                      style: AppText.display(size: 18, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Question ${state.currentQuestionIndex + 1}/${widget.quiz.questions.length}',
                          maxLines: 1,
                          style: AppText.display(
                            size: 30,
                            weight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: CapsuleProgress(
                          value: total > 0
                              ? (state.currentQuestionIndex + 1) / total
                              : 0,
                          tone: Tone.mint,
                          trackColor: Colors.white.withValues(alpha: 0.16),
                          height: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                _TimerDial(
                  key: ValueKey(state.currentQuestionIndex),
                  timeLeft: timeLeft,
                  totalTime: totalTime,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionPage(QuizQuestion question, int pageIndex) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Entrance(
            child: Glass(
              style: GlassStyle.dark,
              blur: Glass.frost,
              borderRadius: BorderRadius.circular(AppRadii.xl),
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question.text,
                    style: AppText.display(
                      size: 23,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(
                        question.multipleAnswersAllowed
                            ? Icons.checklist_rounded
                            : Icons.touch_app_rounded,
                        size: 17,
                        color: AppColors.mintBright,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          question.multipleAnswersAllowed
                              ? AppLocalizations.of(
                                  context,
                                )!.chooseCorrectAnswers
                              : AppLocalizations.of(
                                  context,
                                )!.chooseCorrectAnswer,
                          style: AppText.body(
                            size: 14.5,
                            weight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.84),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(question.options.length, (optionIndex) {
            final isSelected =
                _selectedAnswers[pageIndex]?.contains(optionIndex) ?? false;
            return Entrance.staggered(
              index: optionIndex + 1,
              offset: const Offset(0, 16),
              child: _AnswerCard(
                marker: optionIndex < 26
                    ? String.fromCharCode(65 + optionIndex)
                    : '${optionIndex + 1}',
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
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// The per-question countdown: a large number inside a ring that drains
/// with the time left, both turning coral for the last quarter.
class _TimerDial extends StatelessWidget {
  final int timeLeft;
  final int totalTime;

  const _TimerDial({super.key, required this.timeLeft, required this.totalTime});

  static const double _size = 92;

  @override
  Widget build(BuildContext context) {
    final bool low = !(timeLeft > (totalTime * 0.25));
    final double fraction = totalTime > 0
        ? (timeLeft / totalTime).clamp(0.0, 1.0)
        : 0.0;
    final Color color = low ? AppColors.coral : AppColors.mintBright;

    return SizedBox.square(
      dimension: _size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: fraction),
        duration: AppMotion.reduced(context)
            ? Duration.zero
            : const Duration(seconds: 1),
        builder: (context, value, child) => CustomPaint(
          painter: _DialPainter(value: value, color: color),
          child: child,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedDefaultTextStyle(
              duration: AppMotion.fast,
              style: AppText.display(
                size: 38,
                weight: FontWeight.w800,
                color: low ? AppColors.coral : Colors.white,
                height: 1,
              ),
              child: Text('$timeLeft'),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  final double value;
  final Color color;

  const _DialPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 7.0;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = Colors.white.withValues(alpha: 0.08),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withValues(alpha: 0.16),
    );
    if (value <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_DialPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}

/// One answer: a pane of dark glass that fills mint when chosen.
class _AnswerCard extends StatelessWidget {
  final String marker;
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _AnswerCard({
    required this.marker,
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Semantics(
        selected: isSelected,
        child: Pressable(
          onTap: onTap,
          pressedScale: 0.97,
          child: Glass(
            style: GlassStyle.dark,
            shadow: false,
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: Curves.easeOut,
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.mintBright.withValues(alpha: isSelected ? 1 : 0),
                    AppColors.mint.withValues(alpha: isSelected ? 1 : 0),
                  ],
                ),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: AppMotion.fast,
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? AppColors.ink
                          : Colors.white.withValues(alpha: 0.14),
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: isSelected ? 0 : 0.3,
                        ),
                      ),
                    ),
                    child: Text(
                      marker,
                      style: AppText.display(
                        size: 16,
                        color: isSelected ? AppColors.mintBright : Colors.white,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: AppMotion.fast,
                      style: AppText.body(
                        size: 16,
                        weight: FontWeight.w600,
                        color: isSelected ? AppColors.ink : Colors.white,
                        height: 1.3,
                      ),
                      child: Text(text),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedOpacity(
                    opacity: isSelected ? 1.0 : 0.0,
                    duration: AppMotion.fast,
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The way forward — next question, or submit on the last one. A mint pill
/// with the same arrow the screen has always used.
class _AdvanceButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AdvanceButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: MaterialLocalizations.of(context).continueButtonLabel,
      child: Container(
        height: 58,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: AppGradients.mint,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          boxShadow: AppShadows.glow(AppColors.mint),
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.24),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const [0, 0.55],
          ),
        ),
        child: const Icon(
          Icons.arrow_forward_rounded,
          color: AppColors.ink,
          size: 28,
        ),
      ),
    );
  }
}

/// A dialog pane of smoked glass with white text, for dialogs that open
/// over the aurora, where light glass would wash out to grey.
class _SmokedDialog extends StatelessWidget {
  final Widget child;

  const _SmokedDialog({required this.child});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Glass(
        style: GlassStyle.smoked,
        blur: Glass.frost,
        padding: const EdgeInsets.all(24),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: child,
      ),
    );
  }
}
