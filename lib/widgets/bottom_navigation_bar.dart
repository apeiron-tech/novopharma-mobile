import 'package:flutter/material.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:novopharma/screens/dashboard_home_screen.dart';
import 'package:novopharma/screens/goals_screen.dart';
import 'package:novopharma/screens/leaderboard_screen.dart';
import 'package:novopharma/screens/sales_history_screen.dart';
import 'package:novopharma/screens/barcode_scanner_screen.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';

// Constants for consistent positioning
const double kNavBarHeight = 64.0;
const double kFABGapAboveNavBar = 12.0;

class SharedBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const SharedBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Icon list for the bottom navigation (excluding the center scan button)
    final iconList = <IconData>[
      Icons.home,
      Icons.card_giftcard,
      Icons.bar_chart,
      Icons.receipt_long, // Changed from person
    ];

    final l10n = AppLocalizations.of(context)!;
    final labelList = <String>[
      l10n.navHome,
      l10n.navChallenges,
      l10n.navLeaderboard,
      l10n.navHistory,
    ];

    return AnimatedBottomNavigationBar.builder(
      itemCount: iconList.length,
      tabBuilder: (int index, bool isActive) {
        final color = isActive ? const Color(0xFF1F9BD1) : Colors.grey.shade500;
        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              iconList[index],
              size: 24,
              color: color,
            ),
            const SizedBox(height: 4),
            Text(
              labelList[index],
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            )
          ],
        );
      },
      backgroundColor: Colors.white,
      activeIndex: currentIndex >= 2 ? currentIndex - 1 : currentIndex, // Adjust index for missing center button
      gapLocation: GapLocation.center,
      notchSmoothness: NotchSmoothness.softEdge,
      leftCornerRadius: 20,
      rightCornerRadius: 20,
      onTap: (index) {
        // Adjust index back to account for center button
        int adjustedIndex = index >= 2 ? index + 1 : index;
        
        // Handle navigation based on the adjusted index
        switch (adjustedIndex) {
          case 0: // Home
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const DashboardHomeScreen()),
              (route) => false,
            );
            break;
          case 1: // Challenges
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const GoalsScreen()),
              (route) => false,
            );
            break;
          case 3: // Leaderboard
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LeaderboardScreen()),
              (route) => false,
            );
            break;
          case 4: // History
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const SalesHistoryScreen()),
              (route) => false,
            );
            break;
        }
        
        onTap(adjustedIndex);
      },
      hideAnimationController: null,
      shadow: BoxShadow(
        color: Colors.black.withValues(alpha: 0.1),
        blurRadius: 10,
        offset: const Offset(0, -5),
      ),
    );
  }
}

// Helper widget to create FloatingActionButton and AnimatedBottomNavigationBar
class BottomNavigationScaffoldWrapper extends StatefulWidget {
  final Widget child;
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavigationScaffoldWrapper({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<BottomNavigationScaffoldWrapper> createState() => _BottomNavigationScaffoldWrapperState();
}

class _BottomNavigationScaffoldWrapperState extends State<BottomNavigationScaffoldWrapper> {

  void _openScanner(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BarcodeScannerScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Keep extendBody: true as requested
      body: widget.child, // Use widget.child instead of child
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openScanner(context),
        backgroundColor: Colors.cyan,
        elevation: 10,
        shape: const CircleBorder(),
        child: const Icon(
          Icons.qr_code_scanner,
          color: Colors.white,
          size: 30,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: SharedBottomNavigationBar(
        currentIndex: widget.currentIndex, // Use widget.currentIndex
        onTap: widget.onTap, // Use widget.onTap
      ),
    );
  }
}

// Legacy wrapper for backward compatibility
class BottomNavigationWithFAB extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavigationWithFAB({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SharedBottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
    );
  }
}

