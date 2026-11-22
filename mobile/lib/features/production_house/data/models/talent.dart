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
    return Talent(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] as String,
      location: json['location'] as String,
      bio: json['bio'] as String,
      experienceYears: json['experience_years'] as int,
      isVerified: json['is_verified'] as bool,
      skills: List<String>.from(json['skills'] as List),
    );
  }

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    final first = parts.first[0];
    final second = parts.length > 1 ? parts[1][0] : '';
    return (first + second).toUpperCase();
  }
}