import 'package:flutter/material.dart';
import 'package:novopharma/controllers/badge_provider.dart';
import 'package:novopharma/widgets/badge_card.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  void _showBadgeDetails(BuildContext context, BadgeDisplayInfo badgeInfo) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Image.network(
                badgeInfo.badge.imageUrl,
                height: 90,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.shield_outlined,
                  size: 90,
                  color: Color(0xFFD1D5DB),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                badgeInfo.badge.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                badgeInfo.badge.description,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 24),
              if (badgeInfo.isAwarded)
                _buildInfoChip(
                  icon: Icons.check_circle_outline,
                  label:
                      'Awarded on ${DateFormat.yMMMd().format(badgeInfo.userBadge!.awardedAt)}',
                  color: Colors.green,
                )
              else
                _buildProgressSection(badgeInfo.progress),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(double progress) {
    return Column(
      children: [
        Text(
          'Your Progress',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF3B82F6),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3B82F6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Badges',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFFF9FAFB),
        foregroundColor: Colors.black,
      ),
      backgroundColor: const Color(0xFFF9FAFB),
      body: Consumer<BadgeProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.badges.isEmpty) {
            return const Center(child: Text('No badges available.'));
          }

          final awardedBadges = provider.badges
              .where((b) => b.isAwarded)
              .toList();
          final lockedBadges = provider.badges
              .where((b) => !b.isAwarded)
              .toList();

          return CustomScrollView(
            slivers: [
              _buildSectionHeader('Awarded (${awardedBadges.length})'),
              _buildGrid(awardedBadges),
              _buildSectionHeader('In Progress (${lockedBadges.length})'),
              _buildGrid(lockedBadges),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF374151),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(List<BadgeDisplayInfo> badges) {
    if (badges.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'No badges in this category yet.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12.0,
          mainAxisSpacing: 12.0,
          childAspectRatio: 0.85,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final badgeInfo = badges[index];
          return GestureDetector(
            onTap: () => _showBadgeDetails(context, badgeInfo),
            child: BadgeCard(badgeInfo: badgeInfo),
          );
        }, childCount: badges.length),
      ),
    );
  }
}
