import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/design/design.dart';
import 'package:novopharma/screens/signup_screen.dart';
import 'package:provider/provider.dart';

/// First-run tour: five swipeable pages on the aurora, each with a small
/// animated scene made of glass that shows the feature instead of a
/// screenshot of it.
class IntroductionScreenCustom extends StatefulWidget {
  const IntroductionScreenCustom({super.key});

  @override
  State<IntroductionScreenCustom> createState() =>
      _IntroductionScreenCustomState();
}

class _IntroPage {
  final String title;
  final String body;
  final Widget Function(double t) scene;
  const _IntroPage(this.title, this.body, this.scene);
}

class _IntroductionScreenCustomState extends State<IntroductionScreenCustom>
    with SingleTickerProviderStateMixin {
  final PageController _pages = PageController();
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4600),
  );
  int _index = 0;
  bool _started = false;

  static final List<_IntroPage> _content = [
    _IntroPage(
      'Suivi des ventes',
      'Scannez ou saisissez manuellement vos ventes. Chaque vente enregistrée vous permet de gagner des points.',
      (t) => _ScanScene(t: t),
    ),
    _IntroPage(
      'Récompenses',
      'Échangez vos points contre des crédits Pluxee. Vos efforts ont de la valeur !',
      (t) => _RewardsScene(t: t),
    ),
    _IntroPage(
      'Objectifs',
      'Stimulez vos ventes grâce à des objectifs définis régulièrement.',
      (t) => _GoalsScene(t: t),
    ),
    _IntroPage(
      'Challenges',
      'Débloquez les badges et relevez les défis. Des cadeaux vous attendent !',
      (t) => _BadgesScene(t: t),
    ),
    _IntroPage(
      'Formations',
      'Apprenez. Conseillez mieux. Gagnez plus.',
      (t) => _TrainingScene(t: t),
    ),
  ];

  bool get _isLast => _index == _content.length - 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduced(context)) {
      // A still frame that shows each scene in its finished state.
      _loop.value = 0.8;
    } else {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    _loop.dispose();
    super.dispose();
  }

  void _onIntroEnd(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.markIntroSeen();
    // AuthWrapper will handle navigation to LoginScreen
  }

  void _onSignup(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.markIntroSeen();

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SignupScreen()));
  }

  void _next() {
    _pages.nextPage(duration: AppMotion.slow, curve: AppMotion.emphasized);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const AuroraBackground(),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 10, 10, 0),
                    child: Row(
                      children: [
                        const BrandLogo(height: 34),
                        const Spacer(),
                        AnimatedOpacity(
                          duration: AppMotion.fast,
                          opacity: _isLast ? 0 : 1,
                          child: IgnorePointer(
                            ignoring: _isLast,
                            child: TextButton(
                              onPressed: () => _onIntroEnd(context),
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    Colors.white.withValues(alpha: 0.82),
                              ),
                              child: const Text('Passer'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pages,
                      itemCount: _content.length,
                      onPageChanged: (i) {
                        HapticFeedback.selectionClick();
                        setState(() => _index = i);
                      },
                      itemBuilder: (context, i) => _buildPage(i),
                    ),
                  ),
                  _buildControls(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(int i) {
    final page = _content[i];
    return AnimatedBuilder(
      animation: _pages,
      builder: (context, _) {
        // How far this page is from centre: 0 when settled, ±1 a page away.
        var delta = 0.0;
        if (_pages.hasClients && _pages.position.haveDimensions) {
          delta = (_pages.page ?? _index.toDouble()) - i;
        } else {
          delta = (_index - i).toDouble();
        }
        final width = MediaQuery.sizeOf(context).width;
        final visible = (1 - delta.abs()).clamp(0.0, 1.0);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The scene drifts slower than the page: it sits "behind".
              Expanded(
                child: Transform.translate(
                  offset: Offset(delta * width * 0.35, 0),
                  child: Opacity(
                    opacity: visible,
                    child: Transform.scale(
                      scale: 0.86 + 0.14 * visible,
                      child: Center(
                        child: FittedBox(
                          child: SizedBox(
                            width: 320,
                            height: 300,
                            child: AnimatedBuilder(
                              animation: _loop,
                              builder: (context, _) => page.scene(_loop.value),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // The words lead: they move ahead of the page.
              Transform.translate(
                offset: Offset(-delta * width * 0.25, 0),
                child: Opacity(
                  opacity: Curves.easeIn.transform(visible),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        page.title,
                        style: AppText.display(
                          size: 36,
                          weight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 78,
                        child: Text(
                          page.body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(
                            size: 16.5,
                            height: 1.5,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControls(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: '${_index + 1} / ${_content.length}',
            child: Row(
              children: [
                for (var i = 0; i < _content.length; i++)
                  AnimatedContainer(
                    duration: AppMotion.medium,
                    curve: AppMotion.spring,
                    width: i == _index ? 28 : 9,
                    height: 9,
                    margin: const EdgeInsets.only(right: 7),
                    decoration: BoxDecoration(
                      color: i == _index
                          ? AppColors.mintBright
                          : Colors.white.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          AnimatedSize(
            duration: AppMotion.medium,
            curve: AppMotion.emphasized,
            alignment: Alignment.topCenter,
            child: _isLast
                ? Column(
                    key: const ValueKey('end'),
                    children: [
                      PrimaryButton.mint(
                        label: 'Connexion',
                        onPressed: () => _onIntroEnd(context),
                      ),
                      const SizedBox(height: 12),
                      SecondaryButton(
                        label: "S'inscrire",
                        onDark: true,
                        height: 56,
                        onPressed: () => _onSignup(context),
                      ),
                    ],
                  )
                : PrimaryButton.mint(
                    key: const ValueKey('next'),
                    label: 'Suivant',
                    onPressed: _next,
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Scenes. Each one is a 320 x 300 stage driven by a looping value t in 0..1.
// ---------------------------------------------------------------------------

double _seg(double t, double a, double b) =>
    ((t - a) / (b - a)).clamp(0.0, 1.0);

double _pop(double x) => AppMotion.spring.transform(x.clamp(0.0, 1.0));

Widget _bar(double width, {double alpha = 0.3, double height = 9}) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(height),
      ),
    );

Widget _gainPill(String text, Tone tone) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: tone.gradient,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        boxShadow: AppShadows.glow(tone.color, strength: 0.55),
      ),
      child: Text(
        text,
        style: AppText.display(
          size: 19,
          color: tone == Tone.mint ? AppColors.ink : Colors.white,
        ),
      ),
    );

/// 1 — A product under the scanner: the beam sweeps the barcode and points
/// pop out.
class _ScanScene extends StatelessWidget {
  final double t;
  const _ScanScene({required this.t});

  @override
  Widget build(BuildContext context) {
    final sweep = (1 - math.cos(t * 2 * math.pi)) / 2;
    final gain = _seg(t, 0.5, 0.62);
    final fade = 1 - _seg(t, 0.86, 0.98);

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Transform.rotate(
          angle: -0.07,
          child: Glass(
            style: GlassStyle.dark,
            blur: Glass.frost,
            width: 214,
            height: 262,
            borderRadius: BorderRadius.circular(34),
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: Tone.peach.gradient,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.medication_liquid_rounded,
                        size: 62,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 66,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Positioned.fill(
                        child: CustomPaint(painter: _BarcodePainter()),
                      ),
                      Positioned(
                        top: 2 + sweep * 58,
                        left: -6,
                        right: -6,
                        child: Container(
                          height: 3.5,
                          decoration: BoxDecoration(
                            color: AppColors.mintBright,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: AppShadows.glow(
                              AppColors.mintBright,
                              strength: 0.9,
                            ),
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
        Positioned(
          top: 30 - 26 * _seg(t, 0.5, 0.98),
          right: 14,
          child: Opacity(
            opacity: gain * fade,
            child: Transform.scale(
              scale: _pop(gain),
              child: _gainPill('+25 pts', Tone.mint),
            ),
          ),
        ),
      ],
    );
  }
}

class _BarcodePainter extends CustomPainter {
  const _BarcodePainter();

  static const _widths = [3, 1, 2, 1, 4, 1, 1, 3, 2, 1, 1, 4, 1, 2, 3, 1, 2, 1, 4, 1, 3];

  @override
  void paint(Canvas canvas, Size size) {
    final total = _widths.fold<int>(0, (a, b) => a + b) + _widths.length - 1;
    final unit = size.width / total;
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.92);
    var x = 0.0;
    for (final w in _widths) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 0, w * unit, size.height),
          const Radius.circular(1.5),
        ),
        paint,
      );
      x += (w + 1) * unit;
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter oldDelegate) => false;
}

/// 2 — Points raining into a Pluxee voucher.
class _RewardsScene extends StatelessWidget {
  final double t;
  const _RewardsScene({required this.t});

  @override
  Widget build(BuildContext context) {
    final bump = math.sin(t * 2 * math.pi * 3).abs();

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 6,
          child: Glass(
            style: GlassStyle.dark,
            blur: Glass.frost,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded, color: AppColors.amber, size: 26),
                const SizedBox(width: 10),
                Text(
                  '1 250 pts',
                  style: AppText.display(size: 24, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        // Capsules falling from the balance into the voucher.
        for (var i = 0; i < 4; i++)
          Builder(
            builder: (context) {
              final p = (t * 2 + i / 4) % 1.0;
              final x = (i - 1.5) * 34 + math.sin(p * math.pi * 2 + i) * 8;
              return Positioned(
                top: 74 + 96 * Curves.easeIn.transform(p),
                left: 160 + x - 13,
                child: Opacity(
                  opacity: math.sin(p * math.pi).clamp(0.0, 1.0),
                  child: Transform.rotate(
                    angle: p * 5 + i,
                    child: const Capsule(
                      width: 26,
                      height: 12,
                      left: AppColors.amber,
                      right: Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),
        Positioned(
          bottom: 8,
          child: Transform.scale(
            scale: 1 + 0.018 * bump,
            child: Transform.rotate(
              angle: 0.035,
              child: Glass(
                style: GlassStyle.dark,
                blur: Glass.frost,
                width: 262,
                height: 126,
                borderRadius: BorderRadius.circular(30),
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const BlisterIcon(
                      icon: Icons.card_giftcard_rounded,
                      tone: Tone.amber,
                      size: 70,
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pluxee',
                            style: AppText.display(size: 28, color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              height: 10,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ColoredBox(
                                      color: Colors.white.withValues(alpha: 0.16),
                                    ),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor:
                                        Curves.easeInOut.transform(_seg(t, 0.05, 0.9)),
                                    heightFactor: 1,
                                    child: const DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: AppGradients.amber,
                                      ),
                                    ),
                                  ),
                                ],
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
        ),
      ],
    );
  }
}

/// 3 — An objective filling up until it is reached.
class _GoalsScene extends StatelessWidget {
  final double t;
  const _GoalsScene({required this.t});

  @override
  Widget build(BuildContext context) {
    final progress = Curves.easeInOutCubic.transform(_seg(t, 0.06, 0.62));
    final done = _seg(t, 0.62, 0.72);
    final fade = 1 - _seg(t, 0.92, 1.0);

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Glass(
          style: GlassStyle.dark,
          blur: Glass.frost,
          width: 252,
          height: 260,
          borderRadius: BorderRadius.circular(34),
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Row(
                children: [
                  const BlisterIcon(
                    icon: Icons.flag_rounded,
                    tone: Tone.coral,
                    size: 46,
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _bar(112, alpha: 0.5),
                      const SizedBox(height: 9),
                      _bar(72),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              SizedBox.square(
                dimension: 128,
                child: CustomPaint(
                  painter: _RingPainter(progress),
                  child: Center(
                    child: done > 0
                        ? Transform.scale(
                            scale: _pop(done),
                            child: const Icon(
                              Icons.check_rounded,
                              color: AppColors.mintBright,
                              size: 60,
                            ),
                          )
                        : Text(
                            '${(progress * 100).round()}%',
                            style: AppText.display(size: 32, color: Colors.white),
                          ),
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
        Positioned(
          top: 26 - 14 * done,
          right: 6,
          child: Opacity(
            opacity: done * fade,
            child: Transform.scale(
              scale: _pop(done),
              child: _gainPill('+100 pts', Tone.amber),
            ),
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  const _RingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 13.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withValues(alpha: 0.14),
    );
    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(
          colors: [AppColors.mintBright, AppColors.mint],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// 4 — A blister pack of badges lighting up one by one under a trophy.
class _BadgesScene extends StatelessWidget {
  final double t;
  const _BadgesScene({required this.t});

  static const _icons = [
    Icons.star_rounded,
    Icons.bolt_rounded,
    Icons.favorite_rounded,
    Icons.workspace_premium_rounded,
    Icons.local_fire_department_rounded,
    Icons.military_tech_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final bob = math.sin(t * 2 * math.pi) * 5;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          bottom: 4,
          child: Glass(
            style: GlassStyle.dark,
            blur: Glass.frost,
            width: 276,
            height: 196,
            borderRadius: BorderRadius.circular(34),
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 14,
              crossAxisSpacing: 16,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                for (var i = 0; i < _icons.length; i++)
                  _dome(i, _seg(t, 0.1 + i * 0.11, 0.18 + i * 0.11)),
              ],
            ),
          ),
        ),
        Positioned(
          top: 2 + bob,
          child: Transform.rotate(
            angle: -0.12,
            child: const BlisterIcon(
              icon: Icons.emoji_events_rounded,
              tone: Tone.indigo,
              size: 92,
            ),
          ),
        ),
      ],
    );
  }

  Widget _dome(int i, double lit) {
    final scale = 1 + 0.2 * math.sin(lit * math.pi);
    return Transform.scale(
      scale: scale,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: lit > 0.5 ? Tone.amber.gradient : null,
          color: lit > 0.5 ? null : Colors.white.withValues(alpha: 0.1),
          border: Border.all(
            color: Colors.white.withValues(alpha: lit > 0.5 ? 0.5 : 0.2),
          ),
          boxShadow: lit > 0.5
              ? AppShadows.glow(AppColors.amber, strength: 0.5 * lit)
              : null,
        ),
        child: Icon(
          _icons[i],
          size: 30,
          color: Colors.white.withValues(alpha: lit > 0.5 ? 1 : 0.35),
        ),
      ),
    );
  }
}

/// 5 — A training: the video plays, then the right answer is picked.
class _TrainingScene extends StatelessWidget {
  final double t;
  const _TrainingScene({required this.t});

  @override
  Widget build(BuildContext context) {
    final watched = Curves.easeInOut.transform(_seg(t, 0.04, 0.52));
    final picked = _seg(t, 0.6, 0.7);
    final pulse = 1 + 0.07 * math.sin(t * 2 * math.pi * 2);

    Widget option({required bool correct}) {
      final on = correct ? picked : 0.0;
      return Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Color.lerp(
            Colors.white.withValues(alpha: 0.1),
            AppColors.mint,
            on,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on > 0.5 ? AppColors.ink : Colors.transparent,
                border: Border.all(
                  color: Colors.white.withValues(alpha: on > 0.5 ? 0 : 0.5),
                  width: 1.6,
                ),
              ),
              child: on > 0.5
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: AppColors.mintBright,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Container(
              width: correct ? 120 : 92,
              height: 9,
              decoration: BoxDecoration(
                color: Color.lerp(
                  Colors.white.withValues(alpha: 0.4),
                  AppColors.ink.withValues(alpha: 0.55),
                  on,
                ),
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Glass(
          style: GlassStyle.dark,
          blur: Glass.frost,
          width: 268,
          height: 276,
          borderRadius: BorderRadius.circular(34),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppGradients.indigo,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: Transform.scale(
                      scale: pulse,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.22),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 6,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ColoredBox(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: watched,
                        heightFactor: 1,
                        child: const ColoredBox(color: AppColors.mintBright),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              option(correct: false),
              const SizedBox(height: 8),
              option(correct: true),
            ],
          ),
        ),
        Positioned(
          top: -4,
          left: 4,
          child: Transform.rotate(
            angle: -0.16,
            child: const BlisterIcon(
              icon: Icons.school_rounded,
              tone: Tone.mint,
              size: 66,
            ),
          ),
        ),
      ],
    );
  }
}
