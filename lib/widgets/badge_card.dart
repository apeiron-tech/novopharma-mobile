import 'package:flutter/material.dart';
import 'package:novopharma/controllers/badge_provider.dart';

class BadgeCard extends StatelessWidget {
  final BadgeDisplayInfo badgeInfo;

  const BadgeCard({super.key, required this.badgeInfo});

  @override
  Widget build(BuildContext context) {
    final bool isAwarded = badgeInfo.isAwarded;

    return Container(
      decoration: BoxDecoration(
        color: isAwarded ? Colors.white : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAwarded ? const Color(0xFFE5E7EB) : const Color(0xFFF3F4F6),
        ),
        boxShadow: [
          if (isAwarded)
            BoxShadow(
              color: Colors.blue.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ColorFiltered(
              colorFilter: isAwarded
                  ? const ColorFilter.mode(
                      Colors.transparent,
                      BlendMode.multiply,
                    )
                  : const ColorFilter.matrix(<double>[
                      0.2126,
                      0.7152,
                      0.0722,
                      0,
                      0,
                      0.2126,
                      0.7152,
                      0.0722,
                      0,
                      0,
                      0.2126,
                      0.7152,
                      0.0722,
                      0,
                      0,
                      0,
                      0,
                      0,
                      1,
                      0,
                    ]),
              child: Image.network(
                badgeInfo.badge.imageUrl,
                height: 60,
                width: 60,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.shield_outlined,
                    size: 60,
                    color: Color(0xFFD1D5DB),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: Text(
                  badgeInfo.badge.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isAwarded
                        ? const Color(0xFF111827)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 18, // Fixed height for the bottom widget area
              child: !isAwarded
                  ? (badgeInfo.progress > 0 && badgeInfo.progress < 1
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: badgeInfo.progress,
                              backgroundColor: const Color(0xFFE5E7EB),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF3B82F6),
                              ),
                              minHeight: 6,
                            ),
                          )
                        : const Icon(
                            Icons.lock_outline,
                            size: 18,
                            color: Color(0xFF9CA3AF),
                          ))
                  : null, // No widget when awarded
            ),
          ],
        ),
      ),
    );
  }
}
