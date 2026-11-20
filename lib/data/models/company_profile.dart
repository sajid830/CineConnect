class CompanyProfile {
  final String id;
  final String companyName;
  final String description;
  final String location;
  final String specialization;
  final String email;
  final bool isVerified;
  final String? logoUrl;
  final String? username;
  final String? publicId;
  final String? tagline;
  final String? website;
  final String? contactEmail;
  final String? companyType;
  final int followersCount;
  final int followingCount;

  const CompanyProfile({
    required this.id,
    required this.companyName,
    required this.description,
    required this.location,
    required this.specialization,
    required this.email,
    required this.isVerified,
    this.logoUrl,
    this.username,
    this.publicId,
    this.tagline,
    this.website,
    this.contactEmail,
    this.companyType,
    this.followersCount = 0,
    this.followingCount = 0,
  });

  factory CompanyProfile.fromJson(Map<String, dynamic> json) {
    return CompanyProfile(
      id: json['id'] as String,
      companyName: json['company_name'] as String,
      description: json['description'] as String,
      location: json['location'] as String,
      specialization: json['specialization'] as String,
      email: json['email'] as String,
      isVerified: json['is_verified'] as bool,
      logoUrl: json['logo_url'] as String?,
      username: json['username'] as String?,
      publicId: json['public_id'] as String?,
      tagline: json['tagline'] as String?,
      website: json['website'] as String?,
      contactEmail: json['contact_email'] as String?,
      companyType: json['company_type'] as String?,
      followersCount: (json['followers_count'] as int?) ?? 0,
      followingCount: (json['following_count'] as int?) ?? 0,
    );
  }

  /// The email shown publicly: the contact email if set, else the account email.
  String get shownEmail => contactEmail ?? email;

  List<String> get genres => specialization
      .split(',')
      .map((g) => g.trim())
      .where((g) => g.isNotEmpty)
      .toList();

  String get initials {
    final parts = companyName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final second = parts.length > 1 ? parts[1][0] : '';
    return (parts.first[0] + second).toUpperCase();
  }
}