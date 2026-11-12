import 'package:flutter/material.dart';
import 'package:novopharma/controllers/notification_provider.dart';
import 'package:novopharma/controllers/auth_provider.dart';
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
import '../theme.dart';
import '../generated/l10n/app_localizations.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Configure timeago for French
    timeago.setLocaleMessages('fr', timeago.FrMessages());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightModeColors.lightBackground,
      appBar: AppBar(
        backgroundColor: LightModeColors.lightBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 4,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: LightModeColors.dashboardTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.notifications,
          style: TextStyle(
            color: LightModeColors.dashboardTextPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Consumer2<NotificationProvider, AuthProvider>(
            builder: (context, notificationProvider, authProvider, _) {
              if (notificationProvider.unreadCount == 0)
                return const SizedBox();

              return TextButton(
                onPressed: () {
                  final userId = authProvider.userProfile?.uid;
                  if (userId != null) {
                    notificationProvider.markAllAsRead(userId);
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: LightModeColors.lightPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: Text(
                  AppLocalizations.of(context)!.markAsRead,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer2<NotificationProvider, AuthProvider>(
        builder: (context, notificationProvider, authProvider, _) {
          if (notificationProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = notificationProvider.notifications;

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: LightModeColors.lightSurfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      size: 64,
                      color: LightModeColors.lightOnSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.noNotifications,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: LightModeColors.dashboardTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.notificationsDescription,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: LightModeColors.dashboardTextSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _buildNotificationCard(
                context,
                notification,
                authProvider.userProfile?.uid ?? '',
                notificationProvider,
              );
            },
          );
        },
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
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
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
      child: Container(
        decoration: BoxDecoration(
          color: notification.isRead ? LightModeColors.lightSurface : LightModeColors.lightPrimaryContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: notification.isRead
                ? LightModeColors.lightOutline
                : LightModeColors.lightPrimary,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
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
                        content: Text(AppLocalizations.of(context)!.formationNotFound),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erreur: $e'),
                        backgroundColor: Colors.red,
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
                    MaterialPageRoute(
                      builder: (context) => const GoalsScreen(),
                    ),
                  );
                }
              } else if (notification.type == NotificationType.newBadge ||
                  notification.type == NotificationType.achievement) {
                // Navigate to badges screen
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BadgesScreen(),
                    ),
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
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getNotificationColor(
                        notification.type,
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getNotificationIcon(notification.type),
                      color: _getNotificationColor(notification.type),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: notification.isRead
                                      ? FontWeight.w600
                                      : FontWeight.bold,
                                  color: LightModeColors.dashboardTextPrimary,
                                ),
                              ),
                            ),
                            if (!notification.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1F9BD1),
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.body,
                          style: const TextStyle(
                            fontSize: 14,
                            color: LightModeColors.dashboardTextSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          timeago.format(notification.createdAt, locale: 'fr'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: LightModeColors.lightOnSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
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

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.newTraining:
        return LightModeColors.lightPrimary;
      case NotificationType.newActualite:
        return LightModeColors.novoPharmaBlue;
      case NotificationType.newBadge:
        return LightModeColors.warning;
      case NotificationType.achievement:
        return LightModeColors.success;
      case NotificationType.newGoal:
      case NotificationType.goalCompleted:
        return LightModeColors.novoPharmaBlue;
      case NotificationType.quizCorrection:
        return LightModeColors.novoPharmaBlue;
      case NotificationType.reminder:
        return LightModeColors.lightSecondary;
    }
  }
}
