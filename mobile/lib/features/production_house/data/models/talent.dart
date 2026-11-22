const talentRoles = [
  'Actor',
  'Director',
  'Cinematographer',
  'Editor',
  'Music Composer',
  'Makeup Artist',
];

const talentSkills = [
  'Action',
  'Dance',
  'Dubbing',
  'Colour grading',
  'Drone shooting',
  'Sound design',
  'Editing',
  'Screenwriting',
];

class Talent {
  final String id;
  final String fullName;
  final String role;
  final String location;
  final String bio;
  final int experienceYears;
  final bool isVerified;
  final List<String> skills;

  const Talent({
    required this.id,
    required this.fullName,
    required this.role,
    required this.location,
    required this.bio,
    required this.experienceYears,
    required this.isVerified,
    required this.skills,
  });

  factory Talent.fromJson(Map<String, dynamic> json) {
    List<String> parsedSkills = [];
    if (json['skills'] is List) {
      parsedSkills = (json['skills'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final rawName = json['full_name']?.toString() ?? '';
    final name = rawName.isNotEmpty ? rawName : 'Applicant';

    return Talent(
      id: json['id']?.toString() ?? '',
      fullName: name,
      role: json['role']?.toString() ?? 'Talent',
      location: json['location']?.toString() ?? 'Pan-India',
      bio: json['bio']?.toString() ?? '',
      experienceYears: (json['experience_years'] is num)
          ? (json['experience_years'] as num).toInt()
          : 0,
      isVerified: json['is_verified'] == true,
      skills: parsedSkills,
    );
  }

  Talent copyWith({
    String? id,
    String? fullName,
    String? role,
    String? location,
    String? bio,
    int? experienceYears,
    bool? isVerified,
    List<String>? skills,
  }) {
    return Talent(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      location: location ?? this.location,
      bio: bio ?? this.bio,
      experienceYears: experienceYears ?? this.experienceYears,
      isVerified: isVerified ?? this.isVerified,
      skills: skills ?? this.skills,
    );
  }

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'CC';
    final first = parts.first[0];
    final second = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    return (first + second).toUpperCase();
  }
}