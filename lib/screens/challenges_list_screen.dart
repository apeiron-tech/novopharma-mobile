import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/design/design.dart';
import 'package:novopharma/models/challenge.dart';
import 'package:novopharma/services/challenge_service.dart';
import 'package:novopharma/services/pharmacy_service.dart';
import 'package:novopharma/services/user_service.dart';
import 'package:novopharma/widgets/bottom_navigation_bar.dart';
import 'package:provider/provider.dart';
import 'challenge_details_screen.dart';

class ChallengesListScreen extends StatefulWidget {
  const ChallengesListScreen({super.key});

  @override
  State<ChallengesListScreen> createState() => _ChallengesListScreenState();
}

class _ChallengesListScreenState extends State<ChallengesListScreen> {
  final ChallengeService _challengeService = ChallengeService();
  final UserService _userService = UserService();
  final PharmacyService _pharmacyService = PharmacyService();

  late Future<String?> _userCategoryFuture;

  /// Cards that arrive with the screen. Any further ones are built lazily
  /// and do not animate.
  static const int _leadCards = 3;

  @override
  void initState() {
    super.initState();
    _userCategoryFuture = _loadUserCategory();
  }

  Future<String?> _loadUserCategory() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.firebaseUser?.uid;
    if (userId == null) return null;

    final user = await _userService.getUser(userId);
    if (user != null && user.pharmacyId.isNotEmpty) {
      final pharmacy = await _pharmacyService.getPharmacy(user.pharmacyId);
      final category = pharmacy?.clientCategory;
      return (category == null || category.isEmpty) ? 'Pharmacie' : category;
    }
    return 'Pharmacie'; // Default to Pharmacie if user or pharmacy not found
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationScaffoldWrapper(
      currentIndex: 1, // Fixed index for Challenges
      onTap: (index) {
        // Handled by SharedBottomNavigationBar logic
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InkAppBar(title: "Challenges"),
          Expanded(
            child: FutureBuilder<String?>(
              future: _userCategoryFuture,
              builder: (context, categorySnapshot) {
                if (categorySnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return _buildLoading();
                }

                final category = categorySnapshot.data;
                if (category == null) {
                  return _buildMessage(
                    context,
                    icon: Icons.error_outline_rounded,
                    text: "Erreur lors du chargement des données.",
                    tone: Tone.coral,
                  );
                }

                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final userEmail = authProvider.firebaseUser?.email ?? "";

                return StreamBuilder<List<Challenge>>(
                  stream: _challengeService.getActiveChallenges(category),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildLoading();
                    }

                    if (snapshot.hasError) {
                      return _buildMessage(
                        context,
                        icon: Icons.error_outline_rounded,
                        text: 'Error: ${snapshot.error}',
                        tone: Tone.coral,
                      );
                    }

                    final allChallenges = snapshot.data ?? [];

                    // Filter for "test dev" challenges
                    final challenges = allChallenges.where((challenge) {
                      final isTestDevChallenge = challenge.title.toLowerCase().contains("test dev");
                      if (isTestDevChallenge) {
                        return userEmail.toLowerCase().contains("testdev");
                      }
                      return true;
                    }).toList();

                    if (challenges.isEmpty) {
                      return _buildMessage(
                        context,
                        icon: Icons.emoji_events_rounded,
                        text: "Aucun challenge disponible pour le moment",
                        tone: Tone.indigo,
                      );
                    }

                    return _buildList(context, challenges);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const SkeletonList(
      count: 3,
      itemHeight: 290,
      padding: EdgeInsets.fromLTRB(AppSpace.page, 20, AppSpace.page, 0),
    );
  }

  /// A centred state (empty, error) that scrolls if its text runs long, and
  /// stays clear of the dock.
  Widget _buildMessage(
    BuildContext context, {
    required IconData icon,
    required String text,
    required Tone tone,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: Center(
        child: SingleChildScrollView(
          child: EmptyState(icon: icon, title: text, tone: tone),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<Challenge> challenges) {
    final int leadCount = math.min(challenges.length, _leadCards);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.page,
            20,
            AppSpace.page,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < leadCount; index++)
                  Entrance.staggered(
                    index: index,
                    step: const Duration(milliseconds: 80),
                    child: _buildChallengeCard(context, challenges[index]),
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            AppSpace.page,
            0,
            AppSpace.page,
            MediaQuery.paddingOf(context).bottom + 20,
          ),
          sliver: SliverList.builder(
            itemCount: challenges.length - leadCount,
            itemBuilder: (context, index) {
              return _buildChallengeCard(
                context,
                challenges[index + leadCount],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChallengeCard(BuildContext context, Challenge challenge) {
    final bool hasImage = challenge.imageUrl.isNotEmpty;
    const statusPill = TonePill(
      label: "Actif",
      tone: Tone.mint,
      icon: Icons.bolt_rounded,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: SoftCard(
        padding: EdgeInsets.zero,
        semanticLabel: challenge.title,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ChallengeDetailsScreen(challengeId: challenge.id),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Header with status
            if (hasImage)
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: challenge.imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Shimmer(
                        child: SkeletonBox(height: double.infinity, radius: 0),
                      ),
                      errorWidget: (context, url, error) => const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppGradients.indigo,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.emoji_events_rounded,
                            size: 44,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Gradient overlay
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.ink.withValues(alpha: 0.26),
                              AppColors.ink.withValues(alpha: 0),
                              AppColors.ink.withValues(alpha: 0.36),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Status Badge
                  const Positioned(top: 14, right: 14, child: statusPill),
                ],
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!hasImage) ...[statusPill, const SizedBox(height: 10)],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          challenge.title,
                          style: AppText.display(size: 20, height: 1.15),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: AppColors.indigoTint,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: AppColors.indigoDeep,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    challenge.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(
                      size: 14.5,
                      color: AppColors.textMuted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const TintIcon(
                        icon: Icons.event_rounded,
                        tone: Tone.indigo,
                        size: 40,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Date d'expiration",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.label(
                                size: 12,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDate(challenge.endDate),
                              style: AppText.display(size: 15),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }
}
