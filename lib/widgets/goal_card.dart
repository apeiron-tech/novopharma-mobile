import 'package:flutter/material.dart';
import 'package:novopharma/models/user_goal_progress.dart';
import 'package:novopharma/widgets/progress_ring.dart';
import '../models/goal.dart';

class GoalCard extends StatelessWidget {
  final Goal goal;
  final UserGoalProgress? progress;
  final VoidCallback? onTap;

  const GoalCard({
    super.key,
    required this.goal,
    this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final int currentProgress = progress?.progressValue ?? 0;
    final bool isCompleted = progress?.status == 'completed';
    final double progressPercent = goal.targetValue > 0
        ? (currentProgress / goal.targetValue).clamp(0.0, 1.0)
        : 0.0;

    final Color progressColor =
        isCompleted ? const Color(0xFF22C55E) : const Color(0xFF1F9BD1);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF102040).withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: isCompleted ? progressColor.withOpacity(0.5) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Left Column: Title, Icon, Progress Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Icon
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          goal.metric == 'revenue'
                              ? Icons.monetization_on_outlined
                              : Icons.inventory_2_outlined,
                          color: const Color(0xFF94A3B8),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            goal.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF102132),
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Progress Text
                    Text(
                      goal.metric == 'revenue'
                          ? '$currentProgress / ${goal.targetValue.toInt()} TND'
                          : '$currentProgress / ${goal.targetValue.toInt()} unités',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF4A5568),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Time Remaining
                    _buildChip(
                      icon: Icons.access_time_filled,
                      text: goal.timeRemaining,
                      color: const Color(0xFF4A5568),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Right Column: Progress Ring
              ProgressRing(
                progress: progressPercent,
                size: 80,
                strokeWidth: 8,
                progressColor: progressColor,
                trackColor: const Color(0xFFF0F4F8),
                textStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: progressColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip({required IconData icon, required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
