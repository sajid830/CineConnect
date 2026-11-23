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
      for (final item in res.whereType<Map<String, dynamic>>()) {
        final notif = AppNotification.fromJson(item);
        if (notif.id.isNotEmpty) {
          deduplicated[notif.id] = notif;
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
    final res = await _client.get(ApiEndpoints.unreadNotificationCount);
    if (res is Map<String, dynamic> && res['unread_count'] is num) {
      return (res['unread_count'] as num).toInt();
    }
    throw ApiException(
      statusCode: 500,
      message: 'Invalid response from unread-count endpoint',
    );
  }
}

class MockNotificationRepository implements NotificationRepository {
  List<AppNotification> _items = [
    AppNotification(
      id: 'n1',
      kind: NotificationKind.application,
      title: 'New application',
      body: 'Rohan Iyer applied for Cinematographer.',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      isRead: false,
    ),
    AppNotification(
      id: 'n2',
      kind: NotificationKind.collaboration,
      title: 'Invitation accepted',
      body: 'Rohan Iyer joined Midnight Express.',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      isRead: false,
    ),
    AppNotification(
      id: 'n3',
      kind: NotificationKind.message,
      title: 'New message',
      body: 'Ananya Das: Thank you! Happy to be on board.',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      isRead: false,
    ),
    AppNotification(
      id: 'n4',
      kind: NotificationKind.collaboration,
      title: 'Invitation declined',
      body: 'Vikram Rao declined your invitation to Midnight Express.',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      isRead: true,
    ),
    AppNotification(
      id: 'n5',
      kind: NotificationKind.general,
      title: 'Company verified',
      body: 'Your production house is now verified.',
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      isRead: true,
    ),
  ];

  @override
  Future<List<AppNotification>> getNotifications() async {
    await Future.delayed(const Duration(milliseconds: 600));
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
  const useMock = bool.fromEnvironment('USE_MOCK_PH', defaultValue: true);
  return useMock ? MockNotificationRepository() : RemoteNotificationRepository();
});