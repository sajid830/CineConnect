/// Application user model populated from our PostgreSQL database via FastAPI.
class UserProfile {
  final String id; // Matches the Supabase Auth UUID
  final String email;
  final String accountType; // 'talent' or 'production_house'
  final String? fullName;
  final String? role;
  final String? location;
  final String? bio;
  final String? phone;
  final int experienceYears;
  final bool isVerified;

  UserProfile({
    required this.id,
    required this.email,
    required this.accountType,
    this.fullName,
    this.role,
    this.location,
    this.bio,
    this.phone,
    this.experienceYears = 0,
    this.isVerified = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      accountType: json['account_type'] as String? ?? 'talent',
      fullName: json['full_name'] as String?,
      role: json['role'] as String?,
      location: json['location'] as String?,
      bio: json['bio'] as String?,
      phone: json['phone'] as String?,
      experienceYears: json['experience_years'] as int? ?? 0,
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'account_type': accountType,
      'full_name': fullName,
      'role': role,
      'location': location,
      'bio': bio,
      'phone': phone,
      'experience_years': experienceYears,
      'is_verified': isVerified,
    };
  }
}

