import 'package:flutter/material.dart';
import 'package:novopharma/controllers/notification_provider.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/design/design.dart';
import 'package:novopharma/models/notification_model.dart';
import 'package:novopharma/models/blog_post.dart';
import 'package:novopharma/screens/badges_screen.dart';
import 'package:novopharma/screens/formation_details_screen.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:novopharma/screens/actualites_screen.dart';
import 'package:novopharma/screens/goals_screen.dart';
import 'package:novopharma/screens/quiz_correction_screen.dart';
import '../generated/l10n/app_localizations.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  /// When the list first appeared. Rows built while it is arriving get a
  /// staggered entrance; later builds (scroll, updates) do not replay it.
  DateTime? _listShownAt;

  @override
  void initState() {
    super.initState();
    // Configure timeago for French
    timeago.setLocaleMessages('fr', timeago.FrMessages());
  }

  Widget _arriving(int index, Widget child) {
    _listShownAt ??= DateTime.now();
    final arriving =
        index < 8 &&
        DateTime.now().difference(_listShownAt!) <
            const Duration(milliseconds: 1200);
    return arriving ? Entrance.staggered(index: index, child: child) : child;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: InkAppBar(
        title: AppLocalizations.of(context)!.notifications,
        leading: GlassIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onTap: () => Navigator.pop(context),
        ),
        actions: [
          Consumer2<NotificationProvider, AuthProvider>(
            builder: (context, notificationProvider, authProvider, _) {
              if (notificationProvider.unreadCount == 0) {
                return const SizedBox();
              }

              return GlassIconButton(
                icon: Icons.done_all_rounded,
                tooltip: AppLocalizations.of(context)!.markAsRead,
                onTap: () {
                  final userId = authProvider.userProfile?.uid;
                  if (userId != null) {
                    notificationProvider.markAllAsRead(userId);
                  }
                },
              );
            },
          ),
        ],
      ),
      body: AppBackground(
        child: SizedBox.expand(
          child: Consumer2<NotificationProvider, AuthProvider>(
            builder: (context, notificationProvider, authProvider, _) {
              if (notificationProvider.isLoading) {
                return const SkeletonList(
                  count: 6,
                  itemHeight: 96,
                  padding: EdgeInsets.all(16),
                );
              }

              final notifications = notificationProvider.notifications;

              if (notifications.isEmpty) {
                return EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: AppLocalizations.of(context)!.noNotifications,
                  message: AppLocalizations.of(
                    context,
                  )!.notificationsDescription,
                );
              }

              return ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  16,
                  AppSpace.xl,
                  16,
                  16 + MediaQuery.paddingOf(context).bottom,
                ),
                itemCount: notifications.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return _arriving(
                    index,
                    _buildNotificationCard(
                      context,
                      notification,
                      authProvider.userProfile?.uid ?? '',
                      notificationProvider,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    NotificationModel notification,
    String userId,
    NotificationProvider provider,
  ) {
    return Dismissible(
      key: Key(notification.id),
      background: Container(
        decoration: BoxDecoration(
          gradient: AppGradients.coral,
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        provider.deleteNotification(userId, notification.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.notificationDeleted),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      // Unread rows are tinted and lifted; read ones settle back.
      child: SoftCard(
        radius: AppRadii.md,
        padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
        tint: notification.isRead
            ? null
            : Color.lerp(AppColors.indigoTint, AppColors.indigoBright, 0.16),
        shadow: !notification.isRead,
        onTap: () async {
          // Mark as read
          if (!notification.isRead) {
            await provider.markAsRead(userId, notification.id);
          }

          // Navigate based on notification type
          if (notification.type == NotificationType.newTraining) {
            // Fetch the formation from Firestore
            try {
              final doc = await FirebaseFirestore.instance
                  .collection('blogPosts')
                  .doc(notification.resourceId)
                  .get();

              if (doc.exists && context.mounted) {
                final formation = BlogPost.fromFirestore(doc);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        FormationDetailsScreen(formation: formation),
                  ),
                );
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(context)!.formationNotFound,
                    ),
                    backgroundColor: AppColors.coralDeep,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur: $e'),
                    backgroundColor: AppColors.coralDeep,
                  ),
                );
              }
            }
          } else if (notification.type == NotificationType.newActualite) {
            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ActualitesScreen(),
                ),
              );
            }
          } else if (notification.type == NotificationType.newGoal ||
              notification.type == NotificationType.goalCompleted) {
            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GoalsScreen()),
              );
            }
          } else if (notification.type == NotificationType.newBadge ||
              notification.type == NotificationType.achievement) {
            // Navigate to badges screen
            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BadgesScreen()),
              );
            }
          } else if (notification.type == NotificationType.quizCorrection) {
            if (context.mounted && notification.resourceId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QuizCorrectionScreen(
                    quizId: notification.resourceId!,
                  ),
                ),
              );
            }
          }
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            TintIcon(
              icon: _getNotificationIcon(notification.type),
              tone: _getNotificationTone(notification.type),
              size: 46,
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: AppText.body(
                            size: 15.5,
                            weight: notification.isRead
                                ? FontWeight.w600
                                : FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 9,
                          height: 9,
                          margin: const EdgeInsets.only(left: 8, top: 5),
                          decoration: const BoxDecoration(
                            color: AppColors.indigo,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: AppText.body(size: 14, color: AppColors.textMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timeago.format(notification.createdAt, locale: 'fr'),
                    style: AppText.label(size: 12, weight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.newTraining:
        return Icons.school_rounded;
      case NotificationType.newActualite:
        return Icons.article_rounded;
      case NotificationType.newBadge:
        return Icons.military_tech_rounded;
      case NotificationType.achievement:
        return Icons.emoji_events_rounded;
      case NotificationType.newGoal:
      case NotificationType.goalCompleted:
        return Icons.flag_rounded;
      case NotificationType.quizCorrection:
        return Icons.assignment_turned_in_rounded;
      case NotificationType.reminder:
        return Icons.notifications_active_rounded;
    }
  }

  /// One accent per feature: brand indigo for trainings, news and quizzes,
  /// amber for badges, mint for wins, coral for objectives.
  Tone _getNotificationTone(NotificationType type) {
    switch (type) {
      case NotificationType.newTraining:
        return Tone.indigo;
      case NotificationType.newActualite:
        return Tone.indigo;
      case NotificationType.newBadge:
        return Tone.amber;
      case NotificationType.achievement:
        return Tone.mint;
      case NotificationType.newGoal:
      case NotificationType.goalCompleted:
        return Tone.coral;
      case NotificationType.quizCorrection:
        return Tone.indigo;
      case NotificationType.reminder:
        return Tone.peach;
    }
  }
}
