import 'package:flutter/material.dart' hide Badge;
import 'package:novopharma/models/badge.dart';
import 'package:novopharma/models/user_badge.dart';
import 'package:novopharma/services/badge_service.dart';
import 'package:novopharma/services/user_badge_service.dart';
import 'package:novopharma/services/sale_service.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:collection/collection.dart';

// A wrapper class to hold merged badge data
class BadgeDisplayInfo {
  final Badge badge;
  final UserBadge? userBadge; // Null if not awarded
  final double progress; // 0.0 to 1.0

  BadgeDisplayInfo({
    required this.badge,
    this.userBadge,
    this.progress = 0.0,
  });

  bool get isAwarded => userBadge != null;
}

class BadgeProvider with ChangeNotifier {
  final BadgeService _badgeService = BadgeService();
  final UserBadgeService _userBadgeService = UserBadgeService();
  final SaleService _saleService = SaleService();
  AuthProvider _authProvider;

  List<BadgeDisplayInfo> _badges = [];
  bool _isLoading = false;

  BadgeProvider(this._authProvider) {
    if (_authProvider.userProfile != null) {
      fetchBadges();
    }
  }

  void update(AuthProvider authProvider) {
    // Check if the user has changed (e.g., logged in or out)
    if (authProvider.userProfile?.uid != _authProvider.userProfile?.uid) {
      _authProvider = authProvider;
      if (_authProvider.userProfile != null) {
        fetchBadges();
      } else {
        // User logged out, clear the badges
        _badges = [];
        notifyListeners();
      }
    }
  }

  List<BadgeDisplayInfo> get badges => _badges;
  bool get isLoading => _isLoading;

  Future<void> fetchBadges() async {
    if (_authProvider.userProfile == null) return;

    Future.microtask(() {
      _isLoading = true;
      notifyListeners();
    });

    try {
      final userId = _authProvider.userProfile!.uid;
      final results = await Future.wait([
        _badgeService.getAllBadges(),
        _userBadgeService.getUserBadges(userId),
      ]);

      final allBadges = results[0] as List<Badge>;
      final userBadges = results[1] as List<UserBadge>;

      final List<BadgeDisplayInfo> badgeInfos = [];
      for (final badge in allBadges) {
        final userBadge = userBadges.firstWhereOrNull((ub) => ub.badgeId == badge.id);

        double progress = 0.0;
        if (userBadge != null) {
          progress = 1.0;
        } else {
          progress = await _calculateProgress(badge, userId);
        }

        badgeInfos.add(BadgeDisplayInfo(
          badge: badge,
          userBadge: userBadge,
          progress: progress,
        ));
      }
      _badges = badgeInfos;

    } catch (e) {
      print('Error fetching and merging badges: $e');
      _badges = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<double> _calculateProgress(Badge badge, String userId) async {
    switch (badge.progressMetric) {
      case 'sales_booster':
        return await _calculateSalesBoosterProgress(userId);
      // TODO: Implement other progress metrics like 'brand_champion', 'top_seller'
      default:
        return 0.0;
    }
  }

  Future<double> _calculateSalesBoosterProgress(String userId) async {
    try {
      final now = DateTime.now();
      final prevMonth = DateTime(now.year, now.month - 1, 1);
      final thisMonthStart = DateTime(now.year, now.month, 1);

      final prevMonthSales = await _saleService.getSalesHistory(
        userId,
        startDate: prevMonth,
        endDate: thisMonthStart.subtract(const Duration(days: 1)),
      );

      final thisMonthSales = await _saleService.getSalesHistory(
        userId,
        startDate: thisMonthStart,
        endDate: now,
      );

      final double prevMonthTotal = prevMonthSales.fold(0, (sum, sale) => sum + (sale.totalPrice ?? 0.0));
      final double thisMonthTotal = thisMonthSales.fold(0, (sum, sale) => sum + (sale.totalPrice ?? 0.0));

      if (prevMonthTotal == 0) return 1.0; // If no sales last month, any sale this month is an infinite improvement.

      final target = prevMonthTotal * 1.2;
      if (target == 0) return 1.0;

      final progress = thisMonthTotal / target;
      return progress.clamp(0.0, 1.0); // Clamp between 0 and 1
    } catch (e) {
      print('Error calculating sales booster progress: $e');
      return 0.0;
    }
  }
}
