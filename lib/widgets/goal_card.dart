import 'package:flutter/material.dart';
import 'package:novopharma/design/design.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';
import 'package:novopharma/models/user_goal_progress.dart';
import '../models/goal.dart';

/// One objective: what it is, what it pays, and how far along you are.
/// Coral while in progress, mint once it is done.
class GoalCard extends StatelessWidget {
  final Goal goal;
  final UserGoalProgress? progress;
  final VoidCallback? onTap;

  const GoalCard({super.key, required this.goal, this.progress, this.onTap});

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final int currentProgress = progress?.progressValue ?? 0;
    final bool isCompleted = progress?.status == 'completed';
    final double progressPercent = goal.targetValue > 0
        ? (currentProgress / goal.targetValue).clamp(0.0, 1.0)
        : 0.0;

    final Tone tone = isCompleted ? Tone.mint : Tone.coral;
    final IconData metricIcon = goal.metric == 'revenue'
        ? Icons.payments_rounded
        : Icons.inventory_2_rounded;
    final String target = goal.metric == 'revenue'
        ? '/ ${formatPoints(goal.targetValue.toInt())} TND'
        : '/ ${formatPoints(goal.targetValue.toInt())}';

    return SoftCard(
      onTap: onTap,
      semanticLabel: goal.title,
      tint: isCompleted ? AppColors.mintTint : null,
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isCompleted)
                const BlisterIcon(
                  icon: Icons.check_rounded,
                  tone: Tone.mint,
                  size: 44,
                  glow: false,
                )
              else
                TintIcon(icon: metricIcon, tone: tone, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.display(size: 17, height: 1.18),
                    ),
                    const SizedBox(height: 8),
                    TonePill(
                      label: goal.rewardText,
                      tone: Tone.amber,
                      icon: Icons.star_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatPoints(currentProgress),
                style: AppText.display(size: 26),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  target,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label(size: 13.5, letterSpacing: 0),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(progressPercent * 100).round()}%',
                style: AppText.display(size: 18, color: tone.deep),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: CapsuleProgress(value: progressPercent, tone: tone),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _buildMeta(
                icon: Icons.schedule_rounded,
                text: goal.getTimeRemaining(l10n),
                color: tone.deep,
              ),
              _buildMeta(
                icon: Icons.event_rounded,
                text:
                    '${_formatDate(goal.startDate)} – ${_formatDate(goal.endDate)}',
                color: AppColors.textFaint,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMeta({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.label(size: 12.5, letterSpacing: 0),
          ),
        ),
      ],
    );
  }
}
