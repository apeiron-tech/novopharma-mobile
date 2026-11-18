import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:novopharma/design/design.dart';
import 'package:novopharma/screens/auth_wrapper.dart';

/// Launch sequence: picks up the mark exactly where the native launch
/// screen left it, pulls the capsule apart, snaps it shut with a sparkle and
/// a mint halo, then raises the name while a capsule fills.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2500),
  );

  late final Animation<double> _veil = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.16, curve: Curves.easeOut),
  );
  // The halves draw apart, then snap shut.
  late final Animation<double> _open = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.08, 0.26, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _snap = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.26, 0.42, curve: AppMotion.spring),
  );
  late final Animation<double> _spark = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.38, 0.56, curve: AppMotion.spring),
  );
  late final Animation<double> _nameIn = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.36, 0.6, curve: AppMotion.emphasized),
  );
  late final Animation<double> _fill = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.42, 0.97, curve: Curves.easeInOutCubic),
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _leave();
    });
    _controller.forward();
  }

  void _leave() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AuthWrapper(),
        transitionDuration: const Duration(milliseconds: 520),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: AppMotion.emphasized,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween(begin: 1.04, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
            // Centred exactly where the native launch screen draws the mark.
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final join = 1 - 0.42 * _open.value + 0.42 * _snap.value;
                  final snapped = _controller.value >= 0.34;
                  return PulseRings(
                    color: AppColors.mint,
                    active: snapped,
                    maxScale: 2.1,
                    rings: 3,
                    strength: 0.2,
                    period: const Duration(milliseconds: 3000),
                    child: BrandMark(
                      size: 132,
                      join: join.clamp(0.0, 1.0),
                      spark: snapped ? _spark.value : 1 - _open.value,
                    ),
                  );
                },
              ),
            ),
            Align(
              alignment: const Alignment(0, 0.34),
              child: FadeTransition(
                opacity: _nameIn,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.5),
                    end: Offset.zero,
                  ).animate(_nameIn),
                  child: const BrandWordmark(size: 38),
                ),
              ),
            ),
            // The capsule that fills while the app gets ready.
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.paddingOf(context).bottom + 56,
              child: Center(
                child: FadeTransition(
                  opacity: _nameIn,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 132,
                      height: 10,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ColoredBox(
                              color: Colors.white.withValues(alpha: 0.14),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _fill,
                            builder: (context, _) => FractionallySizedBox(
                              widthFactor: _fill.value,
                              heightFactor: 1,
                              alignment: Alignment.centerLeft,
                              child: const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: AppGradients.mint,
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(10)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Matches the native launch colour, then lifts.
            IgnorePointer(
              child: FadeTransition(
                opacity: ReverseAnimation(_veil),
                child: const ColoredBox(color: AppColors.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
