import 'package:flutter/material.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/models/user_model.dart';
import 'package:novopharma/screens/notifications_screen.dart';
import 'package:novopharma/screens/profile_screen.dart';
import 'package:novopharma/theme.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';

class DashboardHeader extends StatelessWidget {
  final UserModel? user;
  final int unreadNotifications;
  final VoidCallback onNotificationTap;
  final Widget? titleWidget; // New optional parameter

  const DashboardHeader({
    super.key,
    required this.user,
    this.unreadNotifications = 0,
    required this.onNotificationTap,
    this.titleWidget, // Add to constructor
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundImage: NetworkImage(
            user?.avatarUrl ?? 'https://i.pravatar.cc/150?img=3',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: titleWidget ?? Text( 
            user == null
                ? AppLocalizations.of(context)!.welcomeMessage
                : AppLocalizations.of(context)!.welcomeUser(user!.name.split(' ').first),
            style: const TextStyle(
              color: LightModeColors.dashboardTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        GestureDetector(
          onTap: onNotificationTap,
          child: Stack(
            children: [
              const Icon(
                Icons.notifications_none,
                size: 32,
                color: LightModeColors.dashboardTextPrimary,
              ),
              if (unreadNotifications > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(Icons.person_outline, size: 32),
          color: LightModeColors.dashboardTextPrimary,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          },
        ),
      ],
    );
  }
}
