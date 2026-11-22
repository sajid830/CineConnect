enum NotificationKind {
  application,
  collaboration,
  message,
  general;

  static NotificationKind fromApi(String value) {
    return NotificationKind.values.firstWhere(
      (k) => k.name == value,
      orElse: () => NotificationKind.general,
    );
  }
}

class AppNotification {
  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      kind: NotificationKind.fromApi(json['type'] as String),
      title: json['title'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] as bool,
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      kind: kind,
      title: title,
      body: body,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}