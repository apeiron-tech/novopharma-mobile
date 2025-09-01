import 'package:flutter/material.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';
import 'package:novopharma/theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  late Stream<List<NotificationItem>> _notificationsStream;
  late String _userId;

  @override
  void initState() {
    super.initState();
    _userId = Provider.of<AuthProvider>(context, listen: false).firebaseUser!.uid;
    _notificationsStream = _notificationService.getNotifications(_userId);
  }

  void _markAllAsRead() {
    // This functionality is not in the new service, will implement later if needed.
  }

  void _markAsRead(String id) {
    _notificationService.markAsRead(_userId, id);
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightModeColors.novoPharmaLightBlue,
      appBar: AppBar(
        backgroundColor: LightModeColors.novoPharmaLightBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: Text(
              'Mark all as read',
              style: TextStyle(
                color: LightModeColors.novoPharmaBlue,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationItem>>(
        stream: _notificationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No notifications',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            );
          }
          final notifications = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const Divider(
              color: Colors.grey,
              thickness: 0.5,
              height: 1,
            ),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                leading: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: notification.isRead
                        ? Colors.transparent
                        : LightModeColors.novoPharmaBlue,
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(
                  notification.title,
                  style: TextStyle(
                    color: LightModeColors.dashboardTextPrimary,
                    fontSize: 16,
                    fontWeight: notification.isRead
                        ? FontWeight.w500
                        : FontWeight.w600,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      notification.description,
                      style: TextStyle(
                        color: LightModeColors.dashboardTextSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(notification.timestamp),
                      style: TextStyle(
                        color: LightModeColors.dashboardTextTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  if (!notification.isRead) {
                    _markAsRead(notification.id);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}