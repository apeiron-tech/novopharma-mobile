import 'dart:async';
import 'dart:math' as math;
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';
import 'package:novopharma/models/quiz.dart';
import 'package:novopharma/theme.dart';

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
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => const _CongratulationDialog(),
        );
      } else {
        showDialog(
          context: context,
          barrierDismissible: true,
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
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.quizResults),
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
              AppLocalizations.of(context)!.reviewYourAnswers,
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
          child: Text(
            AppLocalizations.of(context)!.done,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, double scorePercentage) {
    final bool hasWon =
        widget.correctAnswers >= widget.quiz.effectiveMinCorrectAnswers;
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Column(
        children: [
          Text(
            hasWon
                ? AppLocalizations.of(context)!.congratulations
                : AppLocalizations.of(context)!.goodEffort,
            style: const TextStyle(
              fontSize: 22,
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
                    hasWon ? Colors.green : Colors.orange,
                  ),
                ),
              ),
              Text(
                '${widget.correctAnswers}/${widget.totalQuestions}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.youEarnedPoints(widget.pointsEarned),
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerReviewList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
    );
  }
}

class _CongratulationDialog extends StatefulWidget {
  const _CongratulationDialog();

  @override
  State<_CongratulationDialog> createState() => _CongratulationDialogState();
}

class _CongratulationDialogState extends State<_CongratulationDialog>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  late AnimationController _loopController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;

  Timer? _countdownTimer;
  int _secondsLeft = 10;
  final int _totalSeconds = 10;

  late List<_ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();

    // Entrance animation
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.elasticOut,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeIn,
    );
    _entranceController.forward();

    // Loop animation for sunburst rotation and trophy pulse
    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(_loopController);
    _pulseAnimation =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.0, end: 1.15),
            weight: 50,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.15, end: 1.0),
            weight: 50,
          ),
        ]).animate(
          CurvedAnimation(parent: _loopController, curve: Curves.easeInOut),
        );

    // Initialize confetti particles
    final random = math.Random();
    _particles = List.generate(45, (index) {
      return _ConfettiParticle(
        x: random.nextDouble() * 300,
        y: random.nextDouble() * -200,
        color: Colors.primaries[random.nextInt(Colors.primaries.length)]
            .withValues(alpha: 0.8),
        size: random.nextDouble() * 8 + 4,
        speedY: random.nextDouble() * 1.5 + 1.0,
        swaySpeed: random.nextDouble() * 2 + 1.0,
        swayWidth: random.nextDouble() * 15 + 5,
        rotationSpeed: random.nextDouble() * 0.1 - 0.05,
      );
    });

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
    _entranceController.dispose();
    _loopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          clipBehavior: Clip.antiAlias,
          elevation: 12,
          backgroundColor: Colors.white,
          child: Stack(
            children: [
              // Confetti particle layer
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _loopController,
                  builder: (context, child) {
                    for (var particle in _particles) {
                      particle.update(_loopController.value);
                    }
                    return CustomPaint(
                      painter: _ConfettiPainter(particles: _particles),
                    );
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 32.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sunburst background + Pulsing Trophy Icon
                    SizedBox(
                      height: 160,
                      width: 160,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _rotationAnimation,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _rotationAnimation.value,
                                child: Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        Colors.amber.withValues(alpha: 0.4),
                                        Colors.amber.withValues(alpha: 0.1),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.3, 0.7, 1.0],
                                    ),
                                  ),
                                  child: CustomPaint(
                                    painter: _SunburstPainter(),
                                  ),
                                ),
                              );
                            },
                          ),
                          ScaleTransition(
                            scale: _pulseAnimation,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.amber.shade50,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withValues(alpha: 0.3),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(20),
                              child: const Icon(
                                Icons.emoji_events_rounded,
                                color: Colors.amber,
                                size: 68,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Congrats message
                    const Text(
                      "wwwelyé vous gagné le quiz",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: LightModeColors.novoPharmaBlue,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Bravo pour votre sans-faute !",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Countdown timer badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              "Fermeture dans $_secondsLeft s",
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Done Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LightModeColors.novoPharmaBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 2,
                        ),
                        child: const Text(
                          "Super !",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Close X button
              Positioned(
                top: 12,
                right: 12,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.grey),
                  splashRadius: 20,
                ),
              ),

              // Animated countdown linear progress indicator at the very bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SizedBox(
                  height: 6,
                  child: LinearProgressIndicator(
                    value: _secondsLeft / _totalSeconds,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.amber,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfettiParticle {
  double x;
  double y;
  final Color color;
  final double size;
  final double speedY;
  final double swaySpeed;
  final double swayWidth;
  final double rotationSpeed;
  double angle = 0;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.color,
    required this.size,
    required this.speedY,
    required this.swaySpeed,
    required this.swayWidth,
    required this.rotationSpeed,
  });

  void update(double progress) {
    y += speedY;
    angle += rotationSpeed;
    // Reset to top if it reaches the bottom of typical dialog height (~400px)
    if (y > 450) {
      y = -20;
    }
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;

  _ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var p in particles) {
      paint.color = p.color;
      canvas.save();
      // Sway left/right based on Y coordinate to look organic
      final double swayX =
          p.x + math.sin(p.y * 0.05 * p.swaySpeed) * p.swayWidth;
      canvas.translate(swayX % size.width, p.y);
      canvas.rotate(p.angle);

      // Draw rectangular or circular confetti alternately
      if (p.size.toInt() % 2 == 0) {
        canvas.drawRect(
          Rect.fromLTWH(-p.size / 2, -p.size / 2, p.size, p.size * 1.5),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _SunburstPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.amber.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.max(size.width, size.height);
    const int rayCount = 12;
    const double angleStep = 2 * math.pi / rayCount;

    for (int i = 0; i < rayCount; i++) {
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          i * angleStep - angleStep / 4,
          angleStep / 2,
          false,
        )
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SorryDialog extends StatefulWidget {
  const _SorryDialog();

  @override
  State<_SorryDialog> createState() => _SorryDialogState();
}

class _SorryDialogState extends State<_SorryDialog>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  late AnimationController _loopController;
  late Animation<double> _pulseAnimation;

  Timer? _countdownTimer;
  int _secondsLeft = 10;
  final int _totalSeconds = 10;

  @override
  void initState() {
    super.initState();

    // Entrance animation
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.elasticOut,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeIn,
    );
    _entranceController.forward();

    // Loop animation for icon pulse
    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseAnimation =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.0, end: 1.1),
            weight: 50,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.1, end: 1.0),
            weight: 50,
          ),
        ]).animate(
          CurvedAnimation(parent: _loopController, curve: Curves.easeInOut),
        );

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
    _entranceController.dispose();
    _loopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          clipBehavior: Clip.antiAlias,
          elevation: 12,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 32.0,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pulsing Sorry Icon
                    SizedBox(
                      height: 120,
                      width: 120,
                      child: Center(
                        child: ScaleTransition(
                          scale: _pulseAnimation,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red.shade50,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withValues(alpha: 0.15),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(20),
                            child: Icon(
                              Icons.sentiment_very_dissatisfied_rounded,
                              color: Colors.red.shade400,
                              size: 60,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Congrats message
                    const Text(
                      "Dommage",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Vous n'avez pas gagné cette fois-ci",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Countdown timer badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              "Fermeture dans $_secondsLeft s",
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Done Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade800,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 2,
                        ),
                        child: const Text(
                          "Fermer",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Animated countdown linear progress indicator at the very bottom
                Positioned(
                  left: -24,
                  right: -24,
                  bottom: -32,
                  child: SizedBox(
                    height: 6,
                    child: LinearProgressIndicator(
                      value: _secondsLeft / _totalSeconds,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.red,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
              AppLocalizations.of(
                context,
              )!.questionNumber(questionNumber, question.text),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (userAnswers.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.noAnswerSelected,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
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
