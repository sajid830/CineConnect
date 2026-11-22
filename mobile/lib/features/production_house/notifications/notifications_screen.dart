import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cineconnect/app/theme.dart';
import 'package:cineconnect/features/production_house/data/models/app_notification.dart';
import 'notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  void _say(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _markAll(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(notificationsProvider.notifier).markAllRead();
    } catch (e) {
      if (context.mounted) _say(context, 'Could not update notifications');
    }
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    AppNotification n,
  ) async {
    if (n.isRead) return;
    try {
      await ref.read(notificationsProvider.notifier).markRead(n.id);
    } catch (e) {
      if (context.mounted) _say(context, 'Could not update notifications');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: unread == 0 ? null : () => _markAll(context, ref),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load notifications'),
              TextButton(
                onPressed: () => ref.invalidate(notificationsProvider),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(notificationsProvider);
            await ref.read(notificationsProvider.future);
          },
          child: items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 160),
                    Center(
                      child: Text(
                        'No notifications yet',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _NotificationTile(
                    notification: items[index],
                    onTap: () => _open(context, ref, items[index]),
                  ),
                ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  IconData get _icon {
    switch (notification.kind) {
      case NotificationKind.application:
        return Icons.assignment_outlined;
      case NotificationKind.collaboration:
        return Icons.group_outlined;
      case NotificationKind.message:
        return Icons.chat_bubble_outline;
      case NotificationKind.general:
        return Icons.notifications_none;
    }
  }

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${t.day}/${t.month}/${t.year}';
  }

  @override
  Widget build(BuildContext context) {
    final n = notification;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: n.isRead ? AppColors.border : AppColors.gold,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: n.isRead ? AppColors.border : AppColors.gold,
              child: Icon(
                _icon,
                size: 20,
                color: n.isRead ? AppColors.textMuted : AppColors.black,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: TextStyle(
                      fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    n.body,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _timeAgo(n.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (!n.isRead)
              const Padding(
                padding: EdgeInsets.only(left: 8, top: 4),
                child: CircleAvatar(radius: 4, backgroundColor: AppColors.gold),
              ),
          ],
        ),
      ),
    );
  }
}