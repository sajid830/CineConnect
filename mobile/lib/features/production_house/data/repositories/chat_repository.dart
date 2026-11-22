import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';

abstract class ChatRepository {
  Future<List<ChatMessage>> getMessages(String collaborationId);

  Future<ChatMessage> send(String collaborationId, String body);

  /// Messages from the other person, pushed as they arrive.
  Stream<ChatMessage> incoming(String collaborationId);

  void dispose();
}

class MockChatRepository implements ChatRepository {
  final _controller = StreamController<ChatMessage>.broadcast();
  int _counter = 0;

  final Map<String, List<ChatMessage>> _store = {
    'c1': [
      ChatMessage(
        id: 'm1',
        collaborationId: 'c1',
        body: 'Hi Rohan, welcome to Midnight Express. Shoot starts in September.',
        sentAt: DateTime.now().subtract(const Duration(days: 2)),
        isMine: true,
      ),
      ChatMessage(
        id: 'm2',
        collaborationId: 'c1',
        body: 'Thank you! Happy to be on board. Can you share the schedule?',
        sentAt: DateTime.now().subtract(const Duration(days: 2, minutes: -5)),
        isMine: false,
      ),
    ],
  };

  static const _replies = [
    'Sounds good!',
    'Got it, thanks for letting me know.',
    'Can we talk about this tomorrow?',
    'Perfect, I will be there.',
  ];

  @override
  Future<List<ChatMessage>> getMessages(String collaborationId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return List.of(_store[collaborationId] ?? const []);
  }

  @override
  Future<ChatMessage> send(String collaborationId, String body) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final message = ChatMessage(
      id: 'mock-${_counter++}',
      collaborationId: collaborationId,
      body: body,
      sentAt: DateTime.now(),
      isMine: true,
    );
    _store.putIfAbsent(collaborationId, () => []).add(message);
    _simulateReply(collaborationId);
    return message;
  }

  void _simulateReply(String collaborationId) {
    Future.delayed(const Duration(seconds: 2), () {
      if (_controller.isClosed) return;
      final reply = ChatMessage(
        id: 'mock-${_counter++}',
        collaborationId: collaborationId,
        body: _replies[_counter % _replies.length],
        sentAt: DateTime.now(),
        isMine: false,
      );
      _store[collaborationId]!.add(reply);
      _controller.add(reply);
    });
  }

  @override
  Stream<ChatMessage> incoming(String collaborationId) {
    return _controller.stream.where((m) => m.collaborationId == collaborationId);
  }

  @override
  void dispose() => _controller.close();
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final repo = MockChatRepository();
  ref.onDispose(repo.dispose);
  return repo;
});