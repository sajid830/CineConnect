import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_notification.dart';

abstract class NotificationRepository {
  Future<List<AppNotification>> getNotifications();

  Future<void> markRead(String id);

  Future<void> markAllRead();
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
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return MockNotificationRepository();
});