import 'package:flutter/material.dart';
import 'package:novopharma/design/design.dart';
import 'package:novopharma/models/user_model.dart';
import 'package:novopharma/screens/profile_screen.dart';
import 'package:novopharma/screens/marques_list_screen.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';

/// The greeting row at the top of the home hero. Sits on ink.
///
/// The avatar opens the profile; the two glass buttons open brand support
/// and notifications.
class DashboardHeader extends StatelessWidget {
  final UserModel? user;
  final int unreadNotifications;
  final VoidCallback onNotificationTap;
  final Widget? titleWidget;

  const DashboardHeader({
    super.key,
    required this.user,
    this.unreadNotifications = 0,
    required this.onNotificationTap,
    this.titleWidget,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final firstName = user?.name.trim().split(RegExp(r'\s+')).first ?? '';

    return Row(
      children: [
        Pressable(
          pressedScale: 0.92,
          semanticLabel: 'Profil',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          },
          child: AppAvatar(
            name: user?.name ?? '',
            imageUrl: user?.avatarUrl,
            size: 50,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: titleWidget ??
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.welcomeMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(
                      size: 13.5,
                      color: Colors.white.withValues(alpha: 0.72),
                      height: 1.2,
                    ),
                  ),
                  if (firstName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      firstName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.display(size: 23, color: Colors.white),
                    ),
                  ],
                ],
              ),
        ),
        const SizedBox(width: 8),
        GlassIconButton(
          icon: Icons.phone_rounded,
          tooltip: 'Assistance marques',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MarquesListScreen(),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        GlassIconButton(
          icon: Icons.notifications_none_rounded,
          tooltip: l10n.notifications,
          showDot: unreadNotifications > 0,
          onTap: onNotificationTap,
        ),
      ],
    );
  }
}
