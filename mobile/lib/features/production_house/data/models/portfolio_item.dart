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
  final String title;
  final PortfolioType type;
  final int year;
  final String? role;
  final String description;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String? genre;
  final String? highlight;

  const PortfolioItem({
    required this.id,
    required this.title,
    required this.type,
    required this.year,
    required this.description,
    this.role,
    this.mediaUrl,
    this.thumbnailUrl,
    this.genre,
    this.highlight,
  });

  factory PortfolioItem.fromJson(Map<String, dynamic> json) {
    return PortfolioItem(
      id: json['id'] as String,
      title: json['title'] as String,
      type: PortfolioType.fromApi(json['media_type'] as String),
      year: json['year'] as int,
      role: json['role'] as String?,
      description: json['description'] as String,
      mediaUrl: json['media_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      genre: json['genre'] as String?,
      highlight: json['highlight'] as String?,
    );
  }
}