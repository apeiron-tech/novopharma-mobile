import 'package:flutter/material.dart';
import 'package:novopharma/controllers/badge_provider.dart';
import '../theme.dart';

class BadgeCard extends StatelessWidget {
  final BadgeDisplayInfo badgeInfo;

  const BadgeCard({super.key, required this.badgeInfo});

  @override
  Widget build(BuildContext context) {
    final bool isAwarded = badgeInfo.isAwarded;

    return Container(
      decoration: BoxDecoration(
        color: isAwarded ? LightModeColors.lightSurface : LightModeColors.lightBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAwarded ? LightModeColors.lightOutline : LightModeColors.lightSurfaceVariant,
        ),
        boxShadow: [
          if (isAwarded)
            BoxShadow(
              color: LightModeColors.lightPrimary.withValues(alpha: 0.1),
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
                    color: LightModeColors.lightOutline,
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
                        ? LightModeColors.dashboardTextPrimary
                        : LightModeColors.dashboardTextSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 16, // Fixed height for the bottom widget area
              child: !isAwarded
                  ? (badgeInfo.progress > 0 && badgeInfo.progress < 1
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: badgeInfo.progress,
                              backgroundColor: LightModeColors.lightOutline,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                LightModeColors.lightPrimary,
                              ),
                              minHeight: 6,
                            ),
                          )
                        : const Icon(
                            Icons.lock_outline,
                            size: 18,
                            color: LightModeColors.lightOutline,
                          ))
                  : null, // No widget when awarded
            ),
          ],
        ),
      ),
    );
  }
}
