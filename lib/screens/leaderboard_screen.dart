import 'package:flutter/material.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/controllers/leaderboard_provider.dart';
import 'package:novopharma/models/user_model.dart';
import 'package:novopharma/theme.dart';
import 'package:novopharma/widgets/bottom_navigation_bar.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late final ScrollController _scrollController;

  final List<List<Color>> _avatarGradients = [
    [Colors.blue.shade300, Colors.blue.shade600],
    [Colors.green.shade300, Colors.green.shade600],
    [Colors.purple.shade300, Colors.purple.shade600],
    [Colors.orange.shade300, Colors.orange.shade600],
    [Colors.teal.shade300, Colors.teal.shade600],
    [Colors.pink.shade300, Colors.pink.shade600],
  ];

  String _formatPoints(num value) {
    final double d = value.toDouble();
    if (d % 1 == 0) {
      return d.toInt().toString();
    }
    return d.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final leaderboardProvider = Provider.of<LeaderboardProvider>(
        context,
        listen: false,
      );
      authProvider.reloadUserProfile();
      leaderboardProvider.fetchLeaderboard(authProvider.firebaseUser?.uid);
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final leaderboardProvider = Provider.of<LeaderboardProvider>(
        context,
        listen: false,
      );
      leaderboardProvider.loadMoreUsers(authProvider.firebaseUser?.uid);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '';
    List<String> names = name.trim().split(' ');
    if (names.length > 1 && names.last.isNotEmpty) {
      return '${names.first[0]}.${names.last[0]}'.toUpperCase();
    } else if (names.isNotEmpty && names.first.isNotEmpty) {
      return names.first[0].toUpperCase();
    }
    return '';
  }

  List<Color> _getAvatarGradient(String userId) {
    final index = userId.hashCode.abs() % _avatarGradients.length;
    return _avatarGradients[index];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BottomNavigationScaffoldWrapper(
      currentIndex: 3, // Leaderboard tab index
      onTap: (index) {},
      child: Consumer<LeaderboardProvider>(
        builder: (context, leaderboardProvider, child) {
          return Container(
            color: Colors.white,
            child: SafeArea(
              child: leaderboardProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Column(
                        children: [
                          _buildHeader(l10n),
                          const SizedBox(height: 20),
                          _buildCurrentUserCard(
                            leaderboardProvider,
                            l10n,
                          ),
                          const SizedBox(height: 20),
                          _buildTopThreeSection(
                            leaderboardProvider.leaderboardData,
                            l10n,
                          ),
                          const SizedBox(height: 20),
                          _buildLeaderboardList(
                            leaderboardProvider,
                            l10n,
                          ),
                        ],
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.userProfile;

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundImage: NetworkImage(
            user?.avatarUrl ?? UserModel.defaultAvatarUrl,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            l10n.nationalRanking,
            style: const TextStyle(
              color: LightModeColors.dashboardTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Icon(
          Icons.notifications_none,
          size: 24,
          color: LightModeColors.dashboardTextPrimary,
        ),
      ],
    );
  }

  Widget _buildCurrentUserCard(
    LeaderboardProvider leaderboardProvider,
    AppLocalizations l10n,
  ) {
    final leaderboardData = leaderboardProvider.leaderboardData;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.firebaseUser?.uid;
    final currentUserInList = leaderboardData.firstWhere(
      (user) => user['userId'] == currentUserId,
      orElse: () => {},
    );
    final String currentRankStr = currentUserInList.isNotEmpty
        ? currentUserInList['rank'].toString()
        : (leaderboardProvider.currentUserRank > 0
            ? leaderboardProvider.currentUserRank.toString()
            : '0');

    final leaderboardAuthProvider = Provider.of<AuthProvider>(
      context,
      listen: false,
    );
    final currentUserProfile = leaderboardAuthProvider.userProfile;
    final userAvailablePoints = currentUserProfile?.availablePoints ?? 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            LightModeColors.lightPrimary,
            LightModeColors.lightSecondary,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: LightModeColors.lightPrimary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles in background
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          // Main content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        l10n.yourRank.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    if (currentRankStr != '0')
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Color(0xFFF59E0B),
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              userAvailablePoints == 0
                                  ? '0'
                                  : '#$currentRankStr',
                              style: const TextStyle(
                                color: Color(0xFF1F2937),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _formatPoints(currentUserProfile?.totalPointsValidated ?? (currentUserInList['totalPointsValidated'] as num?)?.toDouble() ?? 0.0),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'pts',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (currentRankStr != '0')
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.emoji_events_rounded,
                          color: Colors.white.withOpacity(0.9),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            l10n.rankOnMychallenge(
                              currentRankStr,
                              leaderboardProvider.totalUsersCount > 0
                                  ? leaderboardProvider.totalUsersCount
                                  : leaderboardData.length,
                            ),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopThreeSection(
    List<Map<String, dynamic>> leaderboardData,
    AppLocalizations l10n,
  ) {
    if (leaderboardData.isEmpty) return const SizedBox.shrink();
    final topThree = leaderboardData.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LightModeColors.lightSurfaceVariant,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Text(
            l10n.nationalPodium,
            style: TextStyle(
              color: LightModeColors.dashboardTextPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (topThree.length > 1) _buildPodiumItem(topThree[1], 2, 80),
              if (topThree.isNotEmpty) _buildPodiumItem(topThree[0], 1, 100),
              if (topThree.length > 2) _buildPodiumItem(topThree[2], 3, 60),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumItem(
    Map<String, dynamic> user,
    int position,
    double height,
  ) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.firebaseUser?.uid;
    final isCurrentUser = user['userId'] == currentUserId;

    Color medalColor;
    switch (position) {
      case 1:
        medalColor = LightModeColors.lightError;
        break;
      case 2:
        medalColor = Colors.grey.shade400;
        break;
      case 3:
        medalColor = LightModeColors.warning;
        break;
      default:
        medalColor = Colors.grey;
    }

    final num ptsVal = isCurrentUser
        ? (authProvider.userProfile?.totalPointsValidated ?? (user['totalPointsValidated'] as num?)?.toDouble() ?? 0.0)
        : ((user['totalPointsValidated'] ?? user['points'] ?? 0) as num);

    return Column(
      children: [
        if (isCurrentUser)
          CircleAvatar(
            radius: 25,
            backgroundImage: NetworkImage(
              authProvider.userProfile?.avatarUrl ?? UserModel.defaultAvatarUrl,
            ),
          )
        else
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: _getAvatarGradient(user['userId']),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(
                _getInitials(user['name']),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: medalColor, shape: BoxShape.circle),
          child: Icon(Icons.star, color: Colors.white, size: 16),
        ),
        const SizedBox(height: 8),
        Text(
          isCurrentUser ? user['name'] : _getInitials(user['name']),
          style: TextStyle(
            color: LightModeColors.dashboardTextPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${_formatPoints(ptsVal)} pts',
          style: TextStyle(
            color: LightModeColors.dashboardTextPrimary.withOpacity(0.8),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [medalColor.withOpacity(0.8), medalColor],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardList(
    LeaderboardProvider leaderboardProvider,
    AppLocalizations l10n,
  ) {
    final leaderboardData = leaderboardProvider.leaderboardData;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.firebaseUser?.uid;

    return Container(
      decoration: BoxDecoration(
        color: LightModeColors.lightSurface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  l10n.myNationalPosition,
                  style: const TextStyle(
                    color: LightModeColors.dashboardTextPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  l10n.points.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leaderboardData.length,
            separatorBuilder: (context, index) => Divider(
              color: LightModeColors.lightOutline,
              height: 1,
              indent: 20,
              endIndent: 20,
            ),
            itemBuilder: (context, index) {
              final user = leaderboardData[index];
              final isCurrentUser = user['userId'] == currentUserId;

              return Container(
                color: isCurrentUser
                    ? LightModeColors.lightPrimary.withOpacity(0.1)
                    : Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isCurrentUser
                            ? LightModeColors.warning
                            : LightModeColors.lightOutlineVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '${user['rank']}',
                          style: TextStyle(
                            color: isCurrentUser
                                ? Colors.white
                                : LightModeColors.dashboardTextSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (isCurrentUser)
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: NetworkImage(
                          authProvider.userProfile?.avatarUrl ??
                              UserModel.defaultAvatarUrl,
                        ),
                      )
                    else
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: _getAvatarGradient(user['userId']),
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _getInitials(user['name']),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isCurrentUser
                            ? user['name']
                            : _getInitials(user['name']),
                        style: TextStyle(
                          color: LightModeColors.dashboardTextPrimary,
                          fontSize: 14,
                          fontWeight: isCurrentUser
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${user['totalPointsValidated'] ?? user['points']} pts',
                      style: TextStyle(
                        color: isCurrentUser
                            ? LightModeColors.warning
                            : LightModeColors.dashboardTextSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (leaderboardProvider.isLoadingMore)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(
                  color: LightModeColors.lightPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnimatedDateSelector extends StatefulWidget {
  const _AnimatedDateSelector({super.key});

  @override
  State<_AnimatedDateSelector> createState() => _AnimatedDateSelectorState();
}

class _AnimatedDateSelectorState extends State<_AnimatedDateSelector> {
  late final ScrollController _scrollController;
  late final List<Map<String, dynamic>> _days;
  final int _selectedDayIndex = 7; // Today is always the 8th item (index 7)
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // Safely schedule the animation to run after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerToIndex(_selectedDayIndex);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize here because it depends on context for l10n.
    if (!_isInitialized) {
      _generateDays();
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _generateDays() {
    final now = DateTime.now();
    final l10n = AppLocalizations.of(context)!;
    _days = [];

    for (int i = -7; i <= 6; i++) {
      final date = now.add(Duration(days: i));
      final dayNames = [
        '',
        l10n.mon,
        l10n.tue,
        l10n.wed,
        l10n.thu,
        l10n.fri,
        l10n.sat,
        l10n.sun,
      ];
      final label = dayNames[date.weekday];
      _days.add({'day': label, 'date': date.day.toString(), 'isToday': i == 0});
    }
  }

  void _centerToIndex(int index) {
    if (_scrollController.hasClients) {
      const itemWidth = 55.0;
      final viewportWidth = _scrollController.position.viewportDimension;
      final targetOffset =
          (index * itemWidth) - (viewportWidth / 2) + (itemWidth / 2);
      final maxScroll = _scrollController.position.maxScrollExtent;

      _scrollController.animateTo(
        targetOffset.clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: _days.length,
        itemBuilder: (context, index) {
          final day = _days[index];
          final isSelected = index == _selectedDayIndex;
          final isToday = day['isToday'] ?? false;

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () {
                // The selector is not interactive in this version, but tap could be added here.
              },
              child: Container(
                width: 45,
                height: 65,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: isSelected
                        ? Colors.black
                        : (isToday ? Colors.blue : Colors.grey.shade300),
                    width: isToday && !isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      day['day'],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey.shade600,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      day['date'],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
