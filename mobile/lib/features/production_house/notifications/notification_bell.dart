import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cineconnect/app/theme.dart';
import 'notifications_provider.dart';

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadState = ref.watch(unreadCountProvider);
    final count = unreadState.count;

    final bool isLabelVisible;
    final String labelText;
    final Color badgeColor;
    final Color textColor;

    if (unreadState.hasError && count == null) {
      // Represent initial failure without falsely claiming zero unread
      isLabelVisible = true;
      labelText = '!';
      badgeColor = AppColors.error;
      textColor = Colors.white;
    } else if (count != null && count > 0) {
      // Known unread count from server
      isLabelVisible = true;
      labelText = count > 9 ? '9+' : '$count';
      badgeColor = AppColors.gold;
      textColor = AppColors.black;
    } else {
      isLabelVisible = false;
      labelText = '';
      badgeColor = AppColors.gold;
      textColor = AppColors.black;
    }

    final tooltip = unreadState.hasError && count == null
        ? 'Failed to load notifications. Tap to retry.'
        : 'Notifications';

    return IconButton(
      tooltip: tooltip,
      onPressed: () {
        if (unreadState.hasError && count == null) {
          ref.read(unreadCountProvider.notifier).retry();
        }
        context.push('/notifications');
      },
      icon: Badge(
        isLabelVisible: isLabelVisible,
        label: Text(labelText),
        backgroundColor: badgeColor,
        textColor: textColor,
        child: const Icon(Icons.notifications_none),
      ),
    );
  }
}