import 'package:flutter/material.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';
import 'package:novopharma/models/user_goal_progress.dart';
import 'package:novopharma/widgets/progress_ring.dart';
import '../models/goal.dart';

class GoalCard extends StatelessWidget {
  final Goal goal;
  final UserGoalProgress? progress;
  final VoidCallback? onTap;

  const GoalCard({super.key, required this.goal, this.progress, this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final int currentProgress = progress?.progressValue ?? 0;
    final bool isCompleted = progress?.status == 'completed';
    final double progressPercent = goal.targetValue > 0
        ? (currentProgress / goal.targetValue).clamp(0.0, 1.0)
        : 0.0;

    final Color progressColor = isCompleted
        ? const Color(0xFF22C55E)
        : const Color(0xFF1F9BD1);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isCompleted
                ? [
                    Colors.white,
                    const Color(0xFF22C55E).withValues(alpha: 0.05),
                  ]
                : [Colors.white, Colors.grey.shade50],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isCompleted
                ? progressColor.withValues(alpha: 0.3)
                : Colors.grey.shade200,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isCompleted
                  ? progressColor.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative background element
            if (isCompleted)
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: progressColor.withValues(alpha: 0.05),
                  ),
                ),
              ),
            // Main content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  // Left Column: Title, Icon, Progress Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon badge
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isCompleted
                                  ? [
                                      progressColor.withValues(alpha: 0.2),
                                      progressColor.withValues(alpha: 0.1),
                                    ]
                                  : [
                                      const Color(
                                        0xFF1F9BD1,
                                      ).withValues(alpha: 0.1),
                                      const Color(
                                        0xFF1F9BD1,
                                      ).withValues(alpha: 0.05),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            goal.metric == 'revenue'
                                ? Icons.monetization_on_rounded
                                : Icons.inventory_2_rounded,
                            color: isCompleted
                                ? progressColor
                                : const Color(0xFF1F9BD1),
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Title
                        Text(
                          goal.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                            height: 1.3,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        // Progress Text
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                goal.metric == 'revenue'
                                    ? Icons.payments_rounded
                                    : Icons.inventory_rounded,
                                size: 16,
                                color: Colors.grey.shade700,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                goal.metric == 'revenue'
                                    ? '$currentProgress / ${goal.targetValue.toInt()} TND'
                                    : '$currentProgress / ${goal.targetValue.toInt()}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Time Remaining
                        _buildChip(
                          icon: Icons.schedule_rounded,
                          text: goal.getTimeRemaining(l10n),
                          color: isCompleted
                              ? progressColor
                              : const Color(0xFF1F9BD1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Right Column: Progress Ring
                  ProgressRing(
                    progress: progressPercent,
                    size: 90,
                    strokeWidth: 9,
                    progressColor: progressColor,
                    trackColor: Colors.grey.shade200,
                    textStyle: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: progressColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: 0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
