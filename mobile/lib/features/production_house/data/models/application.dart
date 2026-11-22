import 'talent.dart';

enum ApplicationStatus {
  received('received', 'Received'),
  underReview('under_review', 'Under review'),
  shortlisted('shortlisted', 'Shortlisted'),
  rejected('rejected', 'Rejected');

  final String apiValue;
  final String label;
  const ApplicationStatus(this.apiValue, this.label);

  static ApplicationStatus fromApi(String value) {
    return ApplicationStatus.values.firstWhere((s) => s.apiValue == value);
  }
}

class JobApplication {
  final String id;
  final String opportunityId;
  final ApplicationStatus status;
  final String coverLetter;
  final DateTime appliedAt;
  final Talent talent;

  const JobApplication({
    required this.id,
    required this.opportunityId,
    required this.status,
    required this.coverLetter,
    required this.appliedAt,
    required this.talent,
  });

  factory JobApplication.fromJson(Map<String, dynamic> json) {
    return JobApplication(
      id: json['id'] as String,
      opportunityId: json['opportunity_id'] as String,
      status: ApplicationStatus.fromApi(json['status'] as String),
      coverLetter: json['cover_letter'] as String,
      appliedAt: DateTime.parse(json['applied_at'] as String),
      talent: Talent.fromJson(json['talent'] as Map<String, dynamic>),
    );
  }
}