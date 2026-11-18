import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:novopharma/design/design.dart';
import 'package:novopharma/screens/welcome_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // The gradient now colours each page's icon dome; the page itself rests on
  // the aurora.
  final List<OnboardingData> _pages = [
    OnboardingData(
      icon: Icons.emoji_events_rounded,
      title: 'Compete & Win',
      description:
          'Join over 10,000 pharmacies worldwide in exciting competitions and win amazing rewards',
      gradient: [AppColors.indigoBright, AppColors.indigo],
    ),
    OnboardingData(
      icon: Icons.card_giftcard_rounded,
      title: 'Exclusive Rewards',
      description:
          'Unlock exclusive discounts, special offers, and premium benefits for your pharmacy',
      gradient: [AppColors.amber, AppColors.amberDeep],
    ),
    OnboardingData(
      icon: Icons.leaderboard_rounded,
      title: 'Track Progress',
      description:
          'Monitor your performance, climb the leaderboards, and see how you stack up globally',
      gradient: [AppColors.mintBright, AppColors.mint],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < (_pages.length ?? 0) - 1) {
      // FIX: added null check to prevent crash
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      );
    }
  }

  void _skipOnboarding() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quietButton = TextButton.styleFrom(
      foregroundColor: Colors.white,
      minimumSize: const Size(48, 48),
      textStyle: AppText.body(size: 15, weight: FontWeight.w600),
    );

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
                  // Skip button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 60),
                        // Page indicators
                        Row(
                          children: List.generate(
                            _pages.length ??
                                0, // FIX: added null check to prevent crash
                            (index) => AnimatedContainer(
                              duration: AppMotion.medium,
                              curve: AppMotion.emphasized,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: _currentPage == index ? 24 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _currentPage == index
                                    ? AppColors.mintBright
                                    : Colors.white.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _skipOnboarding,
                          style: quietButton,
                          child: const Text('Skip'),
                        ),
                      ],
                    ),
                  ),

                  // PageView
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      itemCount:
                          _pages.length ??
                          0, // FIX: added null check to prevent crash
                      itemBuilder: (context, index) {
                        final page = _pages[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Icon
                              Container(
                                width: 132,
                                height: 132,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: page.gradient,
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.28),
                                  ),
                                  boxShadow: AppShadows.glow(
                                    page.gradient[0],
                                  ),
                                ),
                                child: Icon(
                                  page.icon,
                                  size: 62,
                                  color: Colors.white,
                                ),
                              ),

                              const SizedBox(height: 44),

                              // Title
                              Text(
                                page.title,
                                style: AppText.display(
                                  size: 32,
                                  weight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 16),

                              // Description
                              Text(
                                page.description,
                                style: AppText.body(
                                  size: 16,
                                  height: 1.55,
                                  color: Colors.white.withValues(alpha: 0.82),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom navigation
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 24, 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Previous button (or empty space)
                        _currentPage > 0
                            ? TextButton.icon(
                                onPressed: () {
                                  _pageController.previousPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                style: quietButton,
                                icon: const Icon(
                                  Icons.arrow_back_rounded,
                                  size: 18,
                                ),
                                label: const Text('Back'),
                              )
                            : const SizedBox(),

                        // Next/Get Started button
                        PrimaryButton.mint(
                          label: _currentPage == (_pages.length ?? 0) - 1
                              ? 'Get Started'
                              : 'Next', // FIX: added null check to prevent crash
                          icon: _currentPage ==
                                  (_pages.length ?? 0) -
                                      1 // FIX: added null check to prevent crash
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                          expand: false,
                          height: 52,
                          onPressed: _nextPage,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingData {
  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradient;

  OnboardingData({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
  });
}
