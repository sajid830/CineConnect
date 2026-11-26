import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/app_notification.dart';

abstract class NotificationRepository {
  Future<List<AppNotification>> getNotifications();

  Future<void> markRead(String id);

  Future<void> markAllRead();

  Future<int> getUnreadCount();
}

class RemoteNotificationRepository implements NotificationRepository {
  final ApiClient _client;

  RemoteNotificationRepository({ApiClient? client})
      : _client = client ?? ApiClient();

  @override
  Future<List<AppNotification>> getNotifications() async {
    final res = await _client.get(ApiEndpoints.notifications, queryParams: {'limit': 50});
    if (res is List) {
      final Map<String, AppNotification> deduplicated = {};
      for (final item in res) {
        if (item is Map) {
          try {
            final notif = AppNotification.fromJson(Map<String, dynamic>.from(item));
            if (notif.id.isNotEmpty) {
              deduplicated[notif.id] = notif;
            }
          } catch (_) {}
        }
      }
      return deduplicated.values.toList();
    }
    return [];
  }

  @override
  Future<void> markRead(String id) async {
    await _client.patch(ApiEndpoints.markNotificationRead(id));
  }

  @override
  Future<void> markAllRead() async {
    await _client.patch(ApiEndpoints.markAllNotificationsRead);
  }

  @override
  Future<int> getUnreadCount() async {
    try {
      final res = await _client.get(ApiEndpoints.unreadNotificationCount);
      if (res is Map && res['unread_count'] is num) {
        return (res['unread_count'] as num).toInt();
      }
    } catch (_) {}
    return 0;
  }
}

class MockNotificationRepository implements NotificationRepository {
  List<AppNotification> _items = [];

  @override
  Future<List<AppNotification>> getNotifications() async {
    return List.of(_items);
  }

  @override
  Future<void> markRead(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _items = [
      for (final n in _items) n.id == id ? n.copyWith(isRead: true) : n,
    ];
  }

  @override
  Future<void> markAllRead() async {
    await Future.delayed(const Duration(milliseconds: 400));
    _items = [for (final n in _items) n.copyWith(isRead: true)];
  }

  @override
  Future<int> getUnreadCount() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _items.where((n) => !n.isRead).length;
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return RemoteNotificationRepository();
});