import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:novopharma/screens/dashboard_home_screen.dart';
import 'package:novopharma/screens/formations_screen.dart';
import 'package:novopharma/screens/actualites_screen.dart';
import 'package:novopharma/screens/sales_history_screen.dart';
import 'package:novopharma/screens/barcode_scanner_screen.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import '../theme.dart';
import 'package:novopharma/widgets/sticky_cart_bar.dart';

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
      Icons.school, // Formations icon
      Icons.article, // Actualités/News icon
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
        final color = isActive ? LightModeColors.lightPrimary : LightModeColors.dashboardTextSecondary;
        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(iconList[index], size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              labelList[index],
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        );
      },
      backgroundColor: LightModeColors.lightSurface,
      activeIndex: currentIndex >= 2
          ? currentIndex - 1
          : currentIndex, // Adjust index for missing center button
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
              MaterialPageRoute(
                builder: (context) => const DashboardHomeScreen(),
              ),
              (route) => false,
            );
            break;
          case 1: // Formations
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const FormationsScreen()),
              (route) => false,
            );
            break;
          case 3: // Actualités
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const ActualitesScreen()),
              (route) => false,
            );
            break;
          case 4: // History
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => const SalesHistoryScreen(),
              ),
              (route) => false,
            );
            break;
        }

        onTap(adjustedIndex);
      },
      hideAnimationController: null,
      shadow: BoxShadow(
        color: LightModeColors.lightSurfaceVariant.withOpacity(0.1),
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
  State<BottomNavigationScaffoldWrapper> createState() =>
      _BottomNavigationScaffoldWrapperState();
}

class _BottomNavigationScaffoldWrapperState
    extends State<BottomNavigationScaffoldWrapper> {
  bool _hasActivePharmacy = false;

  @override
  void initState() {
    super.initState();
    _checkActivePharmacy();
  }

  @override
  void didUpdateWidget(BottomNavigationScaffoldWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkActivePharmacy();
  }

  Future<void> _checkActivePharmacy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activePharId = prefs.getString('active_pharmacy_id');
      final activeVisitId = prefs.getString('active_visit_id');
      final hasActive = activePharId != null && activeVisitId != null;
      if (mounted && _hasActivePharmacy != hasActive) {
        setState(() {
          _hasActivePharmacy = hasActive;
        });
      }
    } catch (e) {
      debugPrint("Error checking active pharmacy: $e");
    }
  }

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
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userProfile;
    final isDermo = user?.role == 'Dermo-conseiller';
    final isScannerActive = !isDermo || _hasActivePharmacy;

    return Scaffold(
      extendBody: true, // Keep extendBody: true as requested
      body: widget.child, // Use widget.child instead of child
      floatingActionButton: FloatingActionButton(
        onPressed: isScannerActive ? () => _openScanner(context) : null,
        backgroundColor: isScannerActive ? LightModeColors.lightPrimary : Colors.grey.shade400,
        elevation: isScannerActive ? 10 : 0,
        shape: const CircleBorder(),
        child: const Icon(Icons.qr_code_scanner, color: LightModeColors.lightOnPrimary, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const StickyCartBar(),
          SharedBottomNavigationBar(
            currentIndex: widget.currentIndex,
            onTap: widget.onTap,
          ),
        ],
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
    return SharedBottomNavigationBar(currentIndex: currentIndex, onTap: onTap);
  }
}
