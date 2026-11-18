import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novopharma/design/design.dart';
import 'package:novopharma/screens/dashboard_home_screen.dart';
import 'package:novopharma/screens/formations_screen.dart';
import 'package:novopharma/screens/actualites_screen.dart';
import 'package:novopharma/screens/sales_history_screen.dart';
import 'package:novopharma/screens/barcode_scanner_screen.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/widgets/sticky_cart_bar.dart';

// Constants for consistent positioning
const double kNavBarHeight = 66.0;
const double kFABGapAboveNavBar = 12.0;

const double _kScanSize = 62;
const double _kScanRing = 5;
const double _kScanRaise = 22;
const double _kCenterGap = 86;
const double _kSideMargin = 16;

class _DockTab {
  final int index;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _DockTab(this.index, this.icon, this.activeIcon, this.label);
}

/// The dock: an ink pill floating over the page, with the scanner — the one
/// action this app exists for — glowing mint at its centre like the cross
/// above a pharmacy door.
class SharedBottomNavigationBar extends StatefulWidget {
  /// 0 home, 1 formations, 3 actualités, 4 history. 2 is the scanner.
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback? onScan;
  final bool scanEnabled;

  const SharedBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onScan,
    this.scanEnabled = true,
  });

  /// Where the indicator was on the previous page, so it can travel to its
  /// new place even though each tab is its own route.
  static int? _lastIndex;

  @override
  State<SharedBottomNavigationBar> createState() =>
      _SharedBottomNavigationBarState();
}

class _SharedBottomNavigationBarState extends State<SharedBottomNavigationBar> {
  /// The tab whose screen is really on display, or -1 on a screen that is
  /// not one of the four tabs (profile, leaderboard…). Those screens still
  /// pass a legacy `currentIndex`, which would light the wrong tab.
  late int _activeIndex;
  late int _shownIndex;

  int _resolveActive() {
    for (final index in const [0, 1, 3, 4]) {
      if (_alreadyOn(index)) return index;
    }
    return -1;
  }

  @override
  void initState() {
    super.initState();
    _activeIndex = _resolveActive();
    final last = SharedBottomNavigationBar._lastIndex;
    _shownIndex = (last != null && last >= 0 && _activeIndex >= 0)
        ? last
        : _activeIndex;
    if (_shownIndex != _activeIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _shownIndex = _activeIndex);
      });
    }
    SharedBottomNavigationBar._lastIndex = _activeIndex;
  }

  bool _alreadyOn(int index) {
    switch (index) {
      case 0:
        return context.findAncestorWidgetOfExactType<DashboardHomeScreen>() !=
            null;
      case 1:
        return context.findAncestorWidgetOfExactType<FormationsScreen>() != null;
      case 3:
        return context.findAncestorWidgetOfExactType<ActualitesScreen>() != null;
      case 4:
        return context.findAncestorWidgetOfExactType<SalesHistoryScreen>() !=
            null;
    }
    return false;
  }

  void _go(int index) {
    if (_alreadyOn(index)) return;
    late final WidgetBuilder builder;
    switch (index) {
      case 0:
        builder = (_) => const DashboardHomeScreen();
        break;
      case 1:
        builder = (_) => const FormationsScreen();
        break;
      case 3:
        builder = (_) => const ActualitesScreen();
        break;
      case 4:
        builder = (_) => const SalesHistoryScreen();
        break;
      default:
        return;
    }
    // Tabs cross-fade instead of sliding so the dock holds still.
    Navigator.pushAndRemoveUntil(
      context,
      FadeRoute(builder: builder),
      (route) => false,
    );
    widget.onTap(index);
  }

  int _slotOf(int index) => index >= 3 ? index - 1 : index;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tabs = [
      _DockTab(0, Icons.home_outlined, Icons.home_rounded, l10n.navHome),
      _DockTab(1, Icons.school_outlined, Icons.school_rounded, l10n.navChallenges),
      _DockTab(
        3,
        Icons.article_outlined,
        Icons.article_rounded,
        l10n.navLeaderboard,
      ),
      _DockTab(
        4,
        Icons.receipt_long_outlined,
        Icons.receipt_long_rounded,
        l10n.navHistory,
      ),
    ];

    // viewPadding, not padding: stay put when the keyboard opens.
    final bottomInset =
        math.max(MediaQuery.viewPaddingOf(context).bottom - 10, 12.0);
    const scanOuter = _kScanSize + _kScanRing * 2;
    final hasIndicator = const [0, 1, 3, 4].contains(_shownIndex);

    return SizedBox(
      height: kNavBarHeight + _kScanRaise + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Content dissolves into the canvas as it passes under the dock.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: bottomInset + kNavBarHeight * 0.8,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.canvas.withValues(alpha: 0),
                      AppColors.canvas.withValues(alpha: 0.92),
                    ],
                    stops: const [0, 0.75],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: _kSideMargin,
            right: _kSideMargin,
            bottom: bottomInset,
            height: kNavBarHeight,
            child: Glass(
              style: GlassStyle.smoked,
              blur: Glass.frost,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tabWidth = (constraints.maxWidth - _kCenterGap) / 4;
                  double leftOf(int slot) =>
                      slot < 2 ? slot * tabWidth : _kCenterGap + slot * tabWidth;
                  const indicatorHeight = 50.0;
                  final indicatorWidth = tabWidth - 6;
                  final slot = hasIndicator ? _slotOf(_shownIndex) : 0;

                  return Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 460),
                        curve: AppMotion.spring,
                        left: leftOf(slot) + (tabWidth - indicatorWidth) / 2,
                        top: (kNavBarHeight - indicatorHeight) / 2 - 1,
                        width: indicatorWidth,
                        height: indicatorHeight,
                        child: AnimatedOpacity(
                          duration: AppMotion.fast,
                          opacity: hasIndicator ? 1 : 0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(AppRadii.pill),
                            ),
                          ),
                        ),
                      ),
                      for (final tab in tabs)
                        Positioned(
                          left: leftOf(_slotOf(tab.index)),
                          top: 0,
                          bottom: 0,
                          width: tabWidth,
                          child: _DockItem(
                            tab: tab,
                            active: tab.index == _activeIndex,
                            onTap: () => _go(tab.index),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          Positioned(
            bottom: bottomInset + kNavBarHeight - scanOuter + _kScanRaise,
            child: _ScanButton(
              enabled: widget.scanEnabled,
              onTap: widget.onScan,
            ),
          ),
        ],
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  final _DockTab tab;
  final bool active;
  final VoidCallback onTap;

  const _DockItem({required this.tab, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.white : Colors.white.withValues(alpha: 0.6);
    return Pressable(
      onTap: onTap,
      pressedScale: 0.9,
      semanticLabel: tab.label,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: AppMotion.fast,
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              active ? tab.activeIcon : tab.icon,
              key: ValueKey(active),
              size: 23,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            tab.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.label(
              size: 10.5,
              weight: active ? FontWeight.w700 : FontWeight.w500,
              color: color,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback? onTap;

  const _ScanButton({required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    return PulseRings(
      color: AppColors.mint,
      active: enabled,
      maxScale: 1.55,
      child: Pressable(
        onTap: enabled ? onTap : null,
        pressedScale: 0.9,
        semanticLabel: 'Scanner',
        child: Container(
          width: _kScanSize + _kScanRing * 2,
          height: _kScanSize + _kScanRing * 2,
          padding: const EdgeInsets.all(_kScanRing),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.ink,
          ),
          child: AnimatedContainer(
            duration: AppMotion.medium,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: enabled ? AppGradients.mint : null,
              color: enabled ? null : AppColors.inkLine,
              boxShadow: enabled
                  ? AppShadows.glow(AppColors.mint, strength: 0.5)
                  : const [],
            ),
            child: Icon(
              Icons.qr_code_scanner_rounded,
              size: 29,
              color: enabled
                  ? AppColors.ink
                  : Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }
}

// Helper widget that hosts a page above the dock.
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
      extendBody: true,
      backgroundColor: AppColors.canvas,
      body: AppBackground(child: widget.child),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const StickyCartBar(),
          SharedBottomNavigationBar(
            currentIndex: widget.currentIndex,
            onTap: widget.onTap,
            scanEnabled: isScannerActive,
            onScan: () => _openScanner(context),
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
