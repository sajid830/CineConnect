import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cineconnect/features/production_house/data/models/app_notification.dart';
import 'package:cineconnect/features/production_house/data/repositories/notification_repository.dart';

class NotificationsNotifier extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() {
    return ref.read(notificationRepositoryProvider).getNotifications();
  }

  Future<void> markRead(String id) async {
    await ref.read(notificationRepositoryProvider).markRead(id);
    final List<AppNotification>? current =
        state.maybeWhen(data: (list) => list, orElse: () => null);
    if (current == null) return;
    state = AsyncData([
      for (final n in current) n.id == id ? n.copyWith(isRead: true) : n,
    ]);
  }

  Future<void> markAllRead() async {
    await ref.read(notificationRepositoryProvider).markAllRead();
    final List<AppNotification>? current =
        state.maybeWhen(data: (list) => list, orElse: () => null);
    if (current == null) return;
    state = AsyncData([for (final n in current) n.copyWith(isRead: true)]);
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<AppNotification>>(
  NotificationsNotifier.new,
);

final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).maybeWhen(
        data: (list) => list.where((n) => !n.isRead).length,
        orElse: () => 0,
      );
});