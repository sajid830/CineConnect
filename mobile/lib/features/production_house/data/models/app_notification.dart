enum NotificationKind {
  application,
  collaboration,
  message,
  general;

  static NotificationKind fromApi(String value) {
    final normalized = value.trim().toLowerCase();
    return NotificationKind.values.firstWhere(
      (k) => k.name.toLowerCase() == normalized,
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
    final rawMessage = json['message'] ?? json['body'] ?? '';
    final rawTitle = json['title'] ?? 'Notification';
    final rawCreatedAt = json['created_at'];
    DateTime parsedDate;
    if (rawCreatedAt is String) {
      parsedDate = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return AppNotification(
      id: json['id']?.toString() ?? '',
      kind: NotificationKind.fromApi(json['type']?.toString() ?? ''),
      title: rawTitle.toString(),
      body: rawMessage.toString(),
      createdAt: parsedDate,
      isRead: json['is_read'] == true,
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