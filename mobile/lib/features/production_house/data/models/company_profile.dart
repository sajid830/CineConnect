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
  final String? userId;

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
    this.userId,
  });

  factory CompanyProfile.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString() ?? '';
    final name = json['company_name']?.toString() ?? '';
    final desc = json['description']?.toString() ?? '';
    final loc = json['location']?.toString() ?? '';
    final spec = json['specialization']?.toString() ?? '';
    final email = json['email']?.toString() ?? '';
    final isVerified = json['is_verified'] == true;
    final logo = json['logo_url']?.toString();
    final website = json['website']?.toString();
    final username = json['username']?.toString();
    final publicId = json['public_id']?.toString() ??
        (rawId.length >= 8 ? 'PH-${rawId.substring(0, 8).toUpperCase()}' : null);
    final tagline = json['tagline']?.toString();
    final contactEmail = json['contact_email']?.toString();
    final companyType = json['company_type']?.toString();
    final followers = (json['followers_count'] as num?)?.toInt() ?? 0;
    final following = (json['following_count'] as num?)?.toInt() ?? 0;

    return CompanyProfile(
      id: rawId,
      companyName: name,
      description: desc,
      location: loc,
      specialization: spec,
      email: email,
      isVerified: isVerified,
      logoUrl: logo,
      username: username,
      publicId: publicId,
      tagline: tagline,
      website: website,
      contactEmail: contactEmail,
      companyType: companyType,
      followersCount: followers,
      followingCount: following,
      userId: json['user_id']?.toString(),
    );
  }

  CompanyProfile copyWith({
    String? id,
    String? companyName,
    String? description,
    String? location,
    String? specialization,
    String? email,
    bool? isVerified,
    String? logoUrl,
    String? username,
    String? publicId,
    String? tagline,
    String? website,
    String? contactEmail,
    String? companyType,
    int? followersCount,
    int? followingCount,
    String? userId,
  }) {
    return CompanyProfile(
      id: id ?? this.id,
      companyName: companyName ?? this.companyName,
      description: description ?? this.description,
      location: location ?? this.location,
      specialization: specialization ?? this.specialization,
      email: email ?? this.email,
      isVerified: isVerified ?? this.isVerified,
      logoUrl: logoUrl ?? this.logoUrl,
      username: username ?? this.username,
      publicId: publicId ?? this.publicId,
      tagline: tagline ?? this.tagline,
      website: website ?? this.website,
      contactEmail: contactEmail ?? this.contactEmail,
      companyType: companyType ?? this.companyType,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      userId: userId ?? this.userId,
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