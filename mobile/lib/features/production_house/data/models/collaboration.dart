import 'talent.dart';

enum CollaborationStatus {
  invited('invited', 'Invited'),
  accepted('accepted', 'Accepted'),
  declined('declined', 'Declined');

  final String apiValue;
  final String label;
  const CollaborationStatus(this.apiValue, this.label);

  static CollaborationStatus fromApi(String value) {
    final lower = value.toLowerCase().trim();
    switch (lower) {
      case 'accepted':
      case 'completed':
        return CollaborationStatus.accepted;
      case 'declined':
      case 'rejected':
      case 'cancelled':
        return CollaborationStatus.declined;
      case 'invited':
      default:
        return CollaborationStatus.invited;
    }
  }
}

class Collaboration {
  final String id;
  final String projectId;
  final CollaborationStatus status;
  final DateTime invitedAt;
  final Talent talent;
  final String? role;

  const Collaboration({
    required this.id,
    required this.projectId,
    required this.status,
    required this.invitedAt,
    required this.talent,
    this.role,
  });

  factory Collaboration.fromJson(Map<String, dynamic> json) {
    // Robust date parsing: check invited_at first, fallback to created_at
    DateTime parsedDate = DateTime.now();
    final rawDate = json['invited_at'] ?? json['created_at'];
    if (rawDate != null) {
      final dt = DateTime.tryParse(rawDate.toString());
      if (dt != null) parsedDate = dt;
    }

    // Robust talent extraction: parse nested talent or synthesize fallback from talent_id & role
    Talent parsedTalent;
    if (json['talent'] is Map<String, dynamic>) {
      parsedTalent = Talent.fromJson(json['talent'] as Map<String, dynamic>);
    } else {
      parsedTalent = Talent(
        id: json['talent_id']?.toString() ?? '',
        fullName: 'Collaborator',
        role: json['role']?.toString() ?? 'Talent',
        location: 'Pan-India',
        bio: '',
        experienceYears: 0,
        isVerified: false,
        skills: const [],
      );
    }

    return Collaboration(
      id: json['id']?.toString() ?? '',
      projectId: json['project_id']?.toString() ?? '',
      status: CollaborationStatus.fromApi(json['status']?.toString() ?? 'invited'),
      invitedAt: parsedDate,
      talent: parsedTalent,
      role: json['role']?.toString(),
    );
  }
}
