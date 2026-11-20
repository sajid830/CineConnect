class ChatMessage {
  final String id;
  final String collaborationId;
  final String body;
  final DateTime sentAt;
  final bool isMine;

  const ChatMessage({
    required this.id,
    required this.collaborationId,
    required this.body,
    required this.sentAt,
    required this.isMine,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      collaborationId: json['collaboration_id'] as String,
      body: json['body'] as String,
      sentAt: DateTime.parse(json['sent_at'] as String),
      isMine: json['is_mine'] as bool,
    );
  }
}