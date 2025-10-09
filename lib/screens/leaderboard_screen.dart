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
  final List<List<Color>> _avatarGradients = [
    [Colors.blue.shade300, Colors.blue.shade600],
    [Colors.green.shade300, Colors.green.shade600],
    [Colors.purple.shade300, Colors.purple.shade600],
    [Colors.orange.shade300, Colors.orange.shade600],
    [Colors.teal.shade300, Colors.teal.shade600],
    [Colors.pink.shade300, Colors.pink.shade600],
  ];

  @override
  void initState() {
    super.initState();
    // Data is fetched automatically by the provider's constructor
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
    final List<String> tabs = [
      l10n.daily,
      l10n.weekly,
      l10n.monthly,
      l10n.yearly
    ];
    final List<String> periods = ['daily', 'weekly', 'monthly', 'yearly'];

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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      child: Column(
                        children: [
                          _buildHeader(l10n),
                          const SizedBox(height: 20),
                          _buildCurrentUserCard(
                              leaderboardProvider.leaderboardData, l10n),
                          const SizedBox(height: 20),
                          _buildTabSelector(leaderboardProvider, tabs, periods),
                          const SizedBox(height: 20),
                          _buildTopThreeSection(
                              leaderboardProvider.leaderboardData, l10n),
                          const SizedBox(height: 20),
                          _buildLeaderboardList(
                              leaderboardProvider.leaderboardData, l10n),
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
            l10n.leaderboard,
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

  Widget _buildTabSelector(
      LeaderboardProvider provider, List<String> tabs, List<String> periods) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(tabs.length, (index) {
        final isActive = provider.selectedPeriod == periods[index];
        return Expanded(
          child: GestureDetector(
            onTap: () {
              provider.fetchLeaderboard(periods[index]);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.symmetric(
                  horizontal: index == 0 ? 0 : 4, vertical: 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF1F9BD1)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  tabs[index],
                  style: TextStyle(
                    color: isActive ? Colors.white : const Color(0xFF6B7280),
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCurrentUserCard(
      List<Map<String, dynamic>> leaderboardData, AppLocalizations l10n) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.firebaseUser?.uid;
    final currentUserData = leaderboardData.firstWhere(
      (user) => user['userId'] == currentUserId,
      orElse: () => {'rank': 'N/A', 'points': 0},
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(31, 26, 31, 36),
      decoration: BoxDecoration(
        color: LightModeColors.dashboardTealBlue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.yourRank,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '#${currentUserData['rank']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${currentUserData['points']} pts',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.outOfEmployees(leaderboardData.length),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopThreeSection(
      List<Map<String, dynamic>> leaderboardData, AppLocalizations l10n) {
    if (leaderboardData.isEmpty) return const SizedBox.shrink();
    final topThree = leaderboardData.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LightModeColors.dashboardNavy,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Text(
            l10n.topPerformers,
            style: const TextStyle(
              color: Colors.white,
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
      Map<String, dynamic> user, int position, double height) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.firebaseUser?.uid;
    final isCurrentUser = user['userId'] == currentUserId;

    Color medalColor;
    switch (position) {
      case 1:
        medalColor = Colors.amber;
        break;
      case 2:
        medalColor = Colors.grey.shade400;
        break;
      case 3:
        medalColor = Colors.orange.shade700;
        break;
      default:
        medalColor = Colors.grey;
    }

    return Column(
      children: [
        if (isCurrentUser)
          CircleAvatar(
            radius: 25,
            backgroundImage: NetworkImage(
                authProvider.userProfile?.avatarUrl ??
                    UserModel.defaultAvatarUrl),
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
                    fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: medalColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.star,
            color: Colors.white,
            size: 16,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isCurrentUser ? user['name'] : _getInitials(user['name']),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${user['points']} pts',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                medalColor.withOpacity(0.8),
                medalColor,
              ],
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
      List<Map<String, dynamic>> leaderboardData, AppLocalizations l10n) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.firebaseUser?.uid;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  l10n.allEmployees,
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
              color: Colors.grey.shade200,
              height: 1,
              indent: 20,
              endIndent: 20,
            ),
            itemBuilder: (context, index) {
              final user = leaderboardData[index];
              final isCurrentUser = user['userId'] == currentUserId;

              return Container(
                color: isCurrentUser
                    ? LightModeColors.dashboardLightCyan.withOpacity(0.1)
                    : Colors.transparent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isCurrentUser
                            ? LightModeColors.dashboardLightCyan
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '${user['rank']}',
                          style: TextStyle(
                            color: isCurrentUser
                                ? Colors.white
                                : Colors.grey.shade600,
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
                        backgroundImage: NetworkImage(authProvider
                                .userProfile?.avatarUrl ??
                            UserModel.defaultAvatarUrl),
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
                                color: Colors.white),
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isCurrentUser ? user['name'] : _getInitials(user['name']),
                        style: TextStyle(
                          color: LightModeColors.dashboardTextPrimary,
                          fontSize: 14,
                          fontWeight:
                              isCurrentUser ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${user['points']} pts',
                      style: TextStyle(
                        color: isCurrentUser
                            ? LightModeColors.dashboardLightCyan
                            : Colors.grey.shade600,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}