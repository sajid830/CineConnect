enum PortfolioType {
  film('film', 'Film'),
  showreel('showreel', 'Showreel'),
  photo('photo', 'Photos'),
  audio('audio', 'Audio'),
  other('other', 'Other');

  final String apiValue;
  final String label;
  const PortfolioType(this.apiValue, this.label);

  /// An unknown type from the backend becomes "other", not a crash.
  static PortfolioType fromApi(String value) {
    return PortfolioType.values.firstWhere(
      (t) => t.apiValue == value,
      orElse: () => PortfolioType.other,
    );
  }
}

class PortfolioItem {
  final String id;
  final String? userId;
  final String title;
  final PortfolioType type;
  final int year;
  final String? role;
  final String description;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String? playbackUrl;
  final String? genre;
  final String? highlight;

  const PortfolioItem({
    required this.id,
    this.userId,
    required this.title,
    required this.type,
    required this.year,
    required this.description,
    this.role,
    this.mediaUrl,
    this.thumbnailUrl,
    this.playbackUrl,
    this.genre,
    this.highlight,
  });

  PortfolioItem copyWith({
    String? id,
    String? userId,
    String? title,
    PortfolioType? type,
    int? year,
    String? role,
    String? description,
    String? mediaUrl,
    String? thumbnailUrl,
    String? playbackUrl,
    String? genre,
    String? highlight,
  }) {
    return PortfolioItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      type: type ?? this.type,
      year: year ?? this.year,
      role: role ?? this.role,
      description: description ?? this.description,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      playbackUrl: playbackUrl ?? this.playbackUrl,
      genre: genre ?? this.genre,
      highlight: highlight ?? this.highlight,
    );
  }

  factory PortfolioItem.fromJson(Map<String, dynamic> json) {
    int parsedYear = DateTime.now().year;
    if (json['year'] is num) {
      parsedYear = (json['year'] as num).toInt();
    } else if (json['created_at'] != null) {
      final dt = DateTime.tryParse(json['created_at'].toString());
      if (dt != null) parsedYear = dt.year;
    }

    final rawType = json['media_type']?.toString().toLowerCase() ?? 'other';
    PortfolioType parsedType;
    if (rawType == 'video') {
      parsedType = PortfolioType.showreel;
    } else if (rawType == 'image' || rawType == 'headshot') {
      parsedType = PortfolioType.photo;
    } else if (rawType == 'audio') {
      parsedType = PortfolioType.audio;
    } else {
      parsedType = PortfolioType.fromApi(rawType);
    }

    return PortfolioItem(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? json['talent_id']?.toString(),
      title: json['title']?.toString() ?? 'Untitled Asset',
      type: parsedType,
      year: parsedYear,
      role: json['role']?.toString(),
      description: json['description']?.toString() ?? '',
      mediaUrl: json['media_url']?.toString(),
      thumbnailUrl: json['thumbnail_url']?.toString(),
      playbackUrl: json['playback_url']?.toString() ?? json['media_url']?.toString(),
      genre: json['genre']?.toString(),
      highlight: json['highlight']?.toString(),
    );
  }
}