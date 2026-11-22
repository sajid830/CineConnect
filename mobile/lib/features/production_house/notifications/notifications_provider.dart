import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cineconnect/features/production_house/data/models/app_notification.dart';
import 'package:cineconnect/features/production_house/data/repositories/notification_repository.dart';

class UnreadCountState {
  final int? count;
  final bool isLoading;
  final Object? error;

  const UnreadCountState({
    this.count,
    this.isLoading = false,
    this.error,
  });

  bool get hasError => error != null;
  bool get hasCount => count != null;

  UnreadCountState copyWith({
    int? count,
    bool clearCount = false,
    bool? isLoading,
    Object? error,
    bool clearError = false,
  }) {
    return UnreadCountState(
      count: clearCount ? null : (count ?? this.count),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class UnreadCountNotifier extends Notifier<UnreadCountState> {
  int? _lastKnownCount;

  @override
  UnreadCountState build() {
    _lastKnownCount = null;
    Future.microtask(() => refresh());
    return const UnreadCountState(isLoading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final serverCount = await ref.read(notificationRepositoryProvider).getUnreadCount();
      _lastKnownCount = serverCount;
      state = UnreadCountState(
        count: serverCount,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      // Preserve the last successfully retrieved server unread count.
      // Do NOT replace with zero or fall back to the loaded list of 50 notifications.
      state = UnreadCountState(
        count: _lastKnownCount,
        isLoading: false,
        error: e,
      );
    }
  }

  Future<void> retry() => refresh();

  void decrement() {
    if (_lastKnownCount != null && _lastKnownCount! > 0) {
      _lastKnownCount = _lastKnownCount! - 1;
      state = state.copyWith(count: _lastKnownCount);
    } else if (state.count != null && state.count! > 0) {
      final newCount = state.count! - 1;
      state = state.copyWith(count: newCount);
    }
  }

  void increment() {
    if (_lastKnownCount != null) {
      _lastKnownCount = _lastKnownCount! + 1;
      state = state.copyWith(count: _lastKnownCount);
    } else if (state.count != null) {
      final newCount = state.count! + 1;
      state = state.copyWith(count: newCount);
    }
  }

  void reset() {
    _lastKnownCount = 0;
    state = state.copyWith(count: 0);
  }

  void setCount(int count) {
    _lastKnownCount = count;
    state = state.copyWith(count: count);
  }
}

final unreadCountProvider = NotifierProvider<UnreadCountNotifier, UnreadCountState>(
  UnreadCountNotifier.new,
);

class NotificationsNotifier extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() async {
    final repo = ref.read(notificationRepositoryProvider);
    final items = await repo.getNotifications();
    // Refresh server unread count whenever notification list is fetched
    ref.read(unreadCountProvider.notifier).refresh();
    return items;
  }

  Future<void> markRead(String id) async {
    final List<AppNotification>? current =
        state.maybeWhen(data: (list) => list, orElse: () => null);

    final targetIndex = current?.indexWhere((n) => n.id == id) ?? -1;
    final targetItem = targetIndex != -1 ? current![targetIndex] : null;
    final bool wasUnread = targetItem != null ? !targetItem.isRead : true;

    // 1. Optimistic update on notification list
    if (current != null && wasUnread) {
      state = AsyncData([
        for (final n in current) n.id == id ? n.copyWith(isRead: true) : n,
      ]);
    }

    // 2. Optimistic decrement on unread count
    if (wasUnread) {
      ref.read(unreadCountProvider.notifier).decrement();
    }

    try {
      // 3. Backend request
      await ref.read(notificationRepositoryProvider).markRead(id);
      // 4. On success, refresh the count from the backend to guarantee server accuracy
      await ref.read(unreadCountProvider.notifier).refresh();
    } catch (e) {
      // 5. Rollback on failure
      if (current != null) {
        state = AsyncData(current);
      }
      if (wasUnread) {
        ref.read(unreadCountProvider.notifier).increment();
      }
      rethrow;
    }
  }

  Future<void> markAllRead() async {
    final List<AppNotification>? current =
        state.maybeWhen(data: (list) => list, orElse: () => null);

    final previousCount = ref.read(unreadCountProvider).count;

    // 1. Optimistic update on notification list
    if (current != null) {
      state = AsyncData([for (final n in current) n.copyWith(isRead: true)]);
    }

    // 2. Optimistic reset on unread count
    ref.read(unreadCountProvider.notifier).reset();

    try {
      // 3. Backend request
      await ref.read(notificationRepositoryProvider).markAllRead();
      // 4. On success, refresh count from backend to confirm it is 0
      await ref.read(unreadCountProvider.notifier).refresh();
    } catch (e) {
      // 5. Rollback on failure
      if (current != null) {
        state = AsyncData(current);
      }
      if (previousCount != null) {
        ref.read(unreadCountProvider.notifier).setCount(previousCount);
      }
      rethrow;
    }
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<AppNotification>>(
  NotificationsNotifier.new,
);