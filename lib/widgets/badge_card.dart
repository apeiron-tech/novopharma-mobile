import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:novopharma/controllers/badge_provider.dart';
import 'package:novopharma/design/design.dart';
import 'package:novopharma/widgets/progress_ring.dart';

/// One cell of the badge blister pack: the badge sealed in its dome, its
/// name, and — while it is still locked — how close it is.
class BadgeCard extends StatelessWidget {
  final BadgeDisplayInfo badgeInfo;

  const BadgeCard({super.key, required this.badgeInfo});

  @override
  Widget build(BuildContext context) {
    final bool isAwarded = badgeInfo.isAwarded;
    final bool inProgress =
        !isAwarded && badgeInfo.progress > 0 && badgeInfo.progress < 1;

    return SoftCard(
      radius: AppRadii.md,
      shadow: isAwarded,
      tint: isAwarded ? AppColors.amberTint : AppColors.surfaceSunken,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double dome = math
              .min(constraints.maxWidth * 0.76, constraints.maxHeight - 58)
              .clamp(40.0, 104.0);
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BadgeDome(
                imageUrl: badgeInfo.badge.imageUrl,
                earned: isAwarded,
                size: dome,
                progress: inProgress ? badgeInfo.progress : null,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Center(
                  child: Text(
                    badgeInfo.badge.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label(
                      size: 12.5,
                      weight: FontWeight.w700,
                      letterSpacing: 0,
                      color: isAwarded ? AppColors.text : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 16, // Fixed height for the bottom widget area
                child: !isAwarded
                    ? (inProgress
                          ? Text(
                              '${(badgeInfo.progress * 100).round()}%',
                              maxLines: 1,
                              style: AppText.display(
                                size: 12.5,
                                color: AppColors.amberDeep,
                                height: 1.2,
                              ),
                            )
                          : const Icon(
                              Icons.lock_rounded,
                              size: 15,
                              color: AppColors.textFaint,
                            ))
                    : const Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: AppColors.amber,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A badge image under a glossy dome, like a pill in its blister. Earned
/// badges are in full colour and glow amber; locked ones are desaturated
/// and dimmed, with an optional [progress] ring around the dome.
class BadgeDome extends StatelessWidget {
  final String imageUrl;
  final bool earned;
  final double size;

  /// 0.0 – 1.0. Draws a thin ring around a locked dome when set.
  final double? progress;

  const BadgeDome({
    super.key,
    required this.imageUrl,
    required this.earned,
    this.size = 64,
    this.progress,
  });

  static const _greyscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    final double ring = progress == null ? 0 : math.max(size * 0.07, 4);
    final double inner = size - ring * 2;

    Widget image = Image.network(
      imageUrl,
      height: inner * 0.66,
      width: inner * 0.66,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.shield_rounded,
          size: inner * 0.5,
          color: earned ? AppColors.amberDeep : AppColors.textFaint,
        );
      },
    );
    if (!earned) {
      image = Opacity(
        opacity: 0.6,
        child: ColorFiltered(colorFilter: _greyscale, child: image),
      );
    }

    final dome = SizedBox.square(
      dimension: inner,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: earned
                ? const [Colors.white, AppColors.amberTint]
                : const [AppColors.surface, AppColors.line],
          ),
          border: Border.all(
            color: earned
                ? AppColors.amber.withValues(alpha: 0.6)
                : Colors.white,
            width: 1.2,
          ),
          boxShadow: earned
              ? [
                  BoxShadow(
                    color: AppColors.amber.withValues(alpha: 0.45),
                    blurRadius: inner * 0.32,
                    offset: Offset(0, inner * 0.1),
                  ),
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            image,
            // The highlight where light catches the dome.
            Positioned(
              top: inner * 0.07,
              left: inner * 0.15,
              child: IgnorePointer(
                child: Transform.rotate(
                  angle: -0.5,
                  child: Container(
                    width: inner * 0.44,
                    height: inner * 0.2,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(inner),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: earned ? 0.85 : 0.7),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (progress == null) return dome;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ProgressRing(
            progress: progress!,
            size: size,
            strokeWidth: math.max(size * 0.045, 3),
            showPercentage: false,
            trackColor: AppColors.line,
            progressColor: AppColors.amber,
          ),
          dome,
        ],
      ),
    );
  }
}
