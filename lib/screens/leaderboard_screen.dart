import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/controllers/leaderboard_provider.dart';
import 'package:novopharma/design/design.dart';
import 'package:novopharma/models/user_model.dart';
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

  /// Rows that arrive with the screen. The rest of the ranking is built
  /// lazily and does not animate.
  static const int _leadRows = 6;

  // Deep variants of the feature tones, so white initials stay readable.
  static const List<Tone> _avatarTones = [
    Tone.indigo,
    Tone(AppColors.mintDeep, AppColors.mintDeep, AppColors.mintTint),
    Tone(AppColors.coralDeep, AppColors.coralDeep, AppColors.coralTint),
    Tone(AppColors.amberDeep, AppColors.amberDeep, AppColors.amberTint),
    Tone(AppColors.indigoBright, AppColors.indigo, AppColors.indigoTint),
    Tone(AppColors.inkLine, AppColors.inkSoft, AppColors.indigoTint),
  ];

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

  Tone _getAvatarTone(String userId) {
    final index = userId.hashCode.abs() % _avatarTones.length;
    return _avatarTones[index];
  }

  /// "VOTRE RANG" -> "Votre rang". Leaves mixed-case strings alone.
  String _sentenceCase(String value) {
    if (value.isEmpty || value != value.toUpperCase()) return value;
    return value[0] + value.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BottomNavigationScaffoldWrapper(
      currentIndex: 3, // Leaderboard tab index
      onTap: (index) {},
      child: Consumer<LeaderboardProvider>(
        builder: (context, leaderboardProvider, child) {
          final isLoading = leaderboardProvider.isLoading;
          final bottomInset = MediaQuery.paddingOf(context).bottom + 20;

          return CustomScrollView(
            controller: _scrollController,
            physics: isLoading ? const NeverScrollableScrollPhysics() : null,
            slivers: [
              // Ink hero: where you stand.
              SliverToBoxAdapter(
                child: InkHero(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.page,
                    10,
                    AppSpace.page,
                    26,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(l10n),
                      const SizedBox(height: 22),
                      Entrance(
                        delay: const Duration(milliseconds: 100),
                        scaleFrom: 0.96,
                        child: _buildCurrentUserCard(leaderboardProvider, l10n),
                      ),
                    ],
                  ),
                ),
              ),
              if (isLoading)
                const SliverToBoxAdapter(
                  child: SkeletonList(
                    count: 6,
                    itemHeight: 64,
                    padding: EdgeInsets.fromLTRB(
                      AppSpace.page,
                      22,
                      AppSpace.page,
                      0,
                    ),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.page,
                      24,
                      AppSpace.page,
                      0,
                    ),
                    child: _buildTopThreeSection(
                      leaderboardProvider.leaderboardData,
                      l10n,
                    ),
                  ),
                ),
                ..._buildLeaderboardList(leaderboardProvider, l10n),
              ],
              SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.userProfile;
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return Row(
      children: [
        if (canPop) ...[
          GlassIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onTap: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(
            l10n.nationalRanking,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.display(size: 24, color: Colors.white, height: 1.1),
          ),
        ),
        const SizedBox(width: 12),
        AppAvatar(
          name: user?.name ?? '',
          imageUrl: user?.avatarUrl ?? UserModel.defaultAvatarUrl,
          size: 44,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // The current user's standing — rank and points on dark glass.
  // ---------------------------------------------------------------------

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

    final num validatedPoints =
        currentUserProfile?.totalPointsValidated ??
        (currentUserInList['totalPointsValidated'] as num?)?.toDouble() ??
        0.0;
    final bool hasRank = currentRankStr != '0';
    final int? rankValue = int.tryParse(currentRankStr);
    final muted = Colors.white.withValues(alpha: 0.78);
    final figure = AppText.display(size: 40, color: Colors.white, height: 1.0);

    Widget rank;
    if (userAvailablePoints == 0) {
      rank = Text('0', style: figure, maxLines: 1);
    } else if (rankValue != null) {
      rank = CountUp(
        value: rankValue,
        style: figure,
        format: (v) => '#${v.round()}',
      );
    } else {
      rank = Text('#$currentRankStr', style: figure, maxLines: 1);
    }

    return SoftCard(
      style: GlassStyle.dark,
      blur: Glass.frost,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (hasRank) ...[
                Expanded(
                  flex: 4,
                  child: _buildHeroStat(
                    label: _sentenceCase(l10n.yourRank),
                    labelColor: muted,
                    value: rank,
                  ),
                ),
                Container(
                  width: 1.2,
                  height: 52,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: Colors.white.withValues(alpha: 0.22),
                ),
              ],
              Expanded(
                flex: 6,
                child: _buildHeroStat(
                  label: l10n.points,
                  labelColor: muted,
                  value: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      CountUp(value: validatedPoints, style: figure),
                      const SizedBox(width: 6),
                      Text('pts', style: AppText.label(size: 15, color: muted)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (hasRank) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: AppColors.amber,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.rankOnMychallenge(
                      currentRankStr,
                      leaderboardProvider.totalUsersCount > 0
                          ? leaderboardProvider.totalUsersCount
                          : leaderboardData.length,
                    ),
                    style: AppText.body(
                      size: 13.5,
                      weight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.86),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroStat({
    required String label,
    required Color labelColor,
    required Widget value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.label(size: 12.5, color: labelColor, letterSpacing: 0),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: value,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // The podium — gold in the middle and tallest, silver left, bronze right.
  // ---------------------------------------------------------------------

  Widget _buildTopThreeSection(
    List<Map<String, dynamic>> leaderboardData,
    AppLocalizations l10n,
  ) {
    if (leaderboardData.isEmpty) return const SizedBox.shrink();
    final topThree = leaderboardData.take(3).toList();

    return Entrance(
      delay: const Duration(milliseconds: 180),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.nationalPodium, style: AppText.display(size: 20)),
          const SizedBox(height: 14),
          SoftCard(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            // Reserve the podium's final height so the ranking below does
            // not shift while the steps rise.
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 270),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: topThree.length > 1
                        ? _buildPodiumItem(topThree[1], 2, 80)
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: topThree.isNotEmpty
                        ? _buildPodiumItem(topThree[0], 1, 114)
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: topThree.length > 2
                        ? _buildPodiumItem(topThree[2], 3, 58)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
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
        medalColor = AppColors.gold;
        break;
      case 2:
        medalColor = AppColors.silver;
        break;
      case 3:
        medalColor = AppColors.bronze;
        break;
      default:
        medalColor = AppColors.silver;
    }

    final num ptsVal = isCurrentUser
        ? (authProvider.userProfile?.totalPointsValidated ?? (user['totalPointsValidated'] as num?)?.toDouble() ?? 0.0)
        : ((user['totalPointsValidated'] ?? user['points'] ?? 0) as num);

    final String name = '${user['name'] ?? ''}';
    final double avatarSize = position == 1 ? 66 : 52;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (position == 1) ...[
          const Icon(
            Icons.emoji_events_rounded,
            color: AppColors.gold,
            size: 26,
          ),
          const SizedBox(height: 4),
        ],
        // The avatar, set in its metal.
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.lerp(medalColor, Colors.white, 0.5)!, medalColor],
            ),
            boxShadow: position == 1
                ? AppShadows.glow(AppColors.gold, strength: 0.45)
                : null,
          ),
          child: AppAvatar(
            name: name,
            imageUrl: isCurrentUser
                ? (authProvider.userProfile?.avatarUrl ??
                      UserModel.defaultAvatarUrl)
                : null,
            size: avatarSize,
            ring: false,
            tone: isCurrentUser ? Tone.indigo : _getAvatarTone(user['userId']),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isCurrentUser ? name : _getInitials(name),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppText.label(
            size: 13,
            weight: FontWeight.w700,
            letterSpacing: 0,
            color: isCurrentUser ? AppColors.indigo : AppColors.text,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(formatPoints(ptsVal), style: AppText.display(size: 15)),
              const SizedBox(width: 3),
              Text('pts', style: AppText.label(size: 11.5, letterSpacing: 0)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _PodiumStep(position: position, height: height, color: medalColor),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // The rest of the ranking — glass rows, the first few arriving in turn.
  // ---------------------------------------------------------------------

  List<Widget> _buildLeaderboardList(
    LeaderboardProvider leaderboardProvider,
    AppLocalizations l10n,
  ) {
    final leaderboardData = leaderboardProvider.leaderboardData;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.firebaseUser?.uid;

    // The top three stand on the podium; everyone else is listed here.
    final int restCount = math.max(leaderboardData.length - 3, 0);
    final int leadCount = math.min(restCount, _leadRows);
    const rowPadding = EdgeInsets.symmetric(horizontal: AppSpace.page);

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.page,
            28,
            AppSpace.page,
            14,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  l10n.myNationalPosition,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.display(size: 18, height: 1.15),
                ),
              ),
              const SizedBox(width: 12),
              Text(l10n.points, style: AppText.label(size: 13)),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: rowPadding,
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < leadCount; i++)
                Entrance.staggered(
                  index: i,
                  base: const Duration(milliseconds: 280),
                  child: _buildRankRow(
                    leaderboardData[i + 3],
                    currentUserId,
                    authProvider,
                  ),
                ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: rowPadding,
        sliver: SliverList.builder(
          itemCount: restCount - leadCount,
          itemBuilder: (context, index) {
            return _buildRankRow(
              leaderboardData[index + 3 + leadCount],
              currentUserId,
              authProvider,
            );
          },
        ),
      ),
      if (leaderboardProvider.isLoadingMore)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CapsuleLoader(size: 36)),
          ),
        ),
    ];
  }

  Widget _buildRankRow(
    Map<String, dynamic> user,
    String? currentUserId,
    AuthProvider authProvider,
  ) {
    final isCurrentUser = user['userId'] == currentUserId;
    final String name = '${user['name'] ?? ''}';
    final dynamic rowPoints = user['totalPointsValidated'] ?? user['points'];

    Widget row = SoftCard(
      radius: AppRadii.md,
      shadow: false,
      tint: isCurrentUser ? AppColors.indigoTint : null,
      padding: const EdgeInsets.fromLTRB(6, 10, 16, 10),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${user['rank']}',
                maxLines: 1,
                style: AppText.display(
                  size: 19,
                  color: isCurrentUser
                      ? AppColors.indigo
                      : AppColors.textMuted,
                ),
              ),
            ),
          ),
          AppAvatar(
            name: name,
            imageUrl: isCurrentUser
                ? (authProvider.userProfile?.avatarUrl ??
                      UserModel.defaultAvatarUrl)
                : null,
            size: 42,
            ring: isCurrentUser,
            tone: isCurrentUser ? Tone.indigo : _getAvatarTone(user['userId']),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isCurrentUser ? name : _getInitials(name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(
                size: 15,
                weight: isCurrentUser ? FontWeight.w700 : FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            rowPoints is num ? formatPoints(rowPoints) : '$rowPoints',
            maxLines: 1,
            style: AppText.display(
              size: 16,
              color: isCurrentUser ? AppColors.indigoDeep : AppColors.text,
            ),
          ),
          const SizedBox(width: 4),
          Text('pts', style: AppText.label(size: 12, letterSpacing: 0)),
        ],
      ),
    );

    if (isCurrentUser) {
      // An indigo edge so your own row is findable at a glance.
      row = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: AppColors.indigo.withValues(alpha: 0.42),
            width: 1.4,
          ),
        ),
        child: row,
      );
    }

    return Padding(padding: const EdgeInsets.only(bottom: 8), child: row);
  }
}

/// One step of the podium. Rises out of the card once, third place first.
class _PodiumStep extends StatelessWidget {
  final int position;
  final double height;
  final Color color;

  const _PodiumStep({
    required this.position,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final double start = position == 1 ? 0.3 : (position == 2 ? 0.15 : 0.0);

    final step = Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.sm),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(color, Colors.white, 0.3)!,
            color,
            Color.lerp(color, AppColors.ink, 0.14)!,
          ],
          stops: const [0, 0.45, 1],
        ),
      ),
      child: Stack(
        children: [
          // Gloss along the top edge of the step.
          Positioned(
            top: 5,
            left: 8,
            right: 8,
            height: 5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.1),
            child: Text(
              '$position',
              style: AppText.display(
                size: position == 1 ? 36 : 28,
                color: AppColors.ink.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.reduced(context)
          ? Duration.zero
          : const Duration(milliseconds: 1200),
      curve: Interval(start, 1, curve: AppMotion.emphasized),
      child: step,
      builder: (context, t, child) => ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: t.clamp(0.0, 1.0),
          child: child,
        ),
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
            child: Pressable(
              onTap: () {
                // The selector is not interactive in this version, but tap could be added here.
              },
              child: Container(
                width: 45,
                height: 65,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.ink
                      : Colors.white.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.ink
                        : (isToday ? AppColors.indigo : Colors.white),
                    width: isToday && !isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      day['day'],
                      style: AppText.label(
                        size: 11,
                        weight: FontWeight.w500,
                        color: isSelected ? Colors.white : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      day['date'],
                      style: AppText.display(
                        size: 15,
                        color: isSelected ? Colors.white : AppColors.text,
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
