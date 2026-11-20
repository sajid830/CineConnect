import 'talent.dart';

enum CollaborationStatus {
  invited('invited', 'Invited'),
  accepted('accepted', 'Accepted'),
  declined('declined', 'Declined');

  final String apiValue;
  final String label;
  const CollaborationStatus(this.apiValue, this.label);

  static CollaborationStatus fromApi(String value) {
    return CollaborationStatus.values.firstWhere((s) => s.apiValue == value);
  }
}

class Collaboration {
  final String id;
  final String projectId;
  final CollaborationStatus status;
  final DateTime invitedAt;
  final Talent talent;

  const Collaboration({
    required this.id,
    required this.projectId,
    required this.status,
    required this.invitedAt,
    required this.talent,
  });

  factory Collaboration.fromJson(Map<String, dynamic> json) {
    return Collaboration(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      status: CollaborationStatus.fromApi(json['status'] as String),
      invitedAt: DateTime.parse(json['invited_at'] as String),
      talent: Talent.fromJson(json['talent'] as Map<String, dynamic>),
    );
  }
}