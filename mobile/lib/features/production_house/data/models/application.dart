import 'talent.dart';

enum ApplicationStatus {
  received('received', 'Received'),
  underReview('under_review', 'Under review'),
  shortlisted('shortlisted', 'Shortlisted'),
  accepted('accepted', 'Accepted'),
  rejected('rejected', 'Rejected');

  final String apiValue;
  final String label;
  const ApplicationStatus(this.apiValue, this.label);

  static ApplicationStatus fromApi(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'under_review':
      case 'in_review':
      case 'underdirectorreview':
        return ApplicationStatus.underReview;
      case 'shortlisted':
      case 'call_sheet_hold':
      case 'hold':
        return ApplicationStatus.shortlisted;
      case 'accepted':
      case 'booked':
      case 'contracted':
        return ApplicationStatus.accepted;
      case 'rejected':
      case 'declined':
        return ApplicationStatus.rejected;
      case 'received':
      case 'submitted':
      default:
        return ApplicationStatus.received;
    }
  }
}

class JobApplication {
  final String id;
  final String? opportunityId;
  final String? projectId;
  final String? targetType;
  final String? projectTitle;
  final String? opportunityTitle;
  final ApplicationStatus status;
  final String coverLetter;
  final DateTime appliedAt;
  final Talent talent;
  final String? resumeUrl;
  final String? reelUrl;

  const JobApplication({
    required this.id,
    this.opportunityId,
    this.projectId,
    this.targetType,
    this.projectTitle,
    this.opportunityTitle,
    required this.status,
    required this.coverLetter,
    required this.appliedAt,
    required this.talent,
    this.resumeUrl,
    this.reelUrl,
  });

  factory JobApplication.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString() ?? '';
    final oppId = json['opportunity_id']?.toString();
    final projId = json['project_id']?.toString();
    final target = json['target_type']?.toString() ?? (projId != null && projId.isNotEmpty ? 'project' : 'opportunity');
    final projTitle = json['project_title']?.toString();
    final oppTitle = json['opportunity_title']?.toString();
    final status = ApplicationStatus.fromApi(json['status']?.toString());
    final coverLetter = json['cover_letter']?.toString() ?? '';

    DateTime applied;
    if (json['applied_at'] != null && json['applied_at'].toString().isNotEmpty) {
      applied = DateTime.tryParse(json['applied_at'].toString()) ?? DateTime.now();
    } else if (json['created_at'] != null && json['created_at'].toString().isNotEmpty) {
      applied = DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now();
    } else {
      applied = DateTime.now();
    }

    Talent talent;
    if (json['talent'] is Map) {
      talent = Talent.fromJson(Map<String, dynamic>.from(json['talent'] as Map));
    } else {
      talent = Talent(
        id: json['talent_id']?.toString() ?? '',
        fullName: 'Applicant',
        role: 'Talent',
        location: 'Pan-India',
        bio: '',
        experienceYears: 0,
        isVerified: false,
        skills: const [],
      );
    }

    return JobApplication(
      id: rawId,
      opportunityId: oppId,
      projectId: projId,
      targetType: target,
      projectTitle: projTitle,
      opportunityTitle: oppTitle,
      status: status,
      coverLetter: coverLetter,
      appliedAt: applied,
      talent: talent,
      resumeUrl: json['resume_url']?.toString(),
      reelUrl: json['reel_url']?.toString(),
    );
  }

  JobApplication copyWith({
    String? id,
    String? opportunityId,
    String? projectId,
    String? targetType,
    String? projectTitle,
    String? opportunityTitle,
    ApplicationStatus? status,
    String? coverLetter,
    DateTime? appliedAt,
    Talent? talent,
    String? resumeUrl,
    String? reelUrl,
  }) {
    return JobApplication(
      id: id ?? this.id,
      opportunityId: opportunityId ?? this.opportunityId,
      projectId: projectId ?? this.projectId,
      targetType: targetType ?? this.targetType,
      projectTitle: projectTitle ?? this.projectTitle,
      opportunityTitle: opportunityTitle ?? this.opportunityTitle,
      status: status ?? this.status,
      coverLetter: coverLetter ?? this.coverLetter,
      appliedAt: appliedAt ?? this.appliedAt,
      talent: talent ?? this.talent,
      resumeUrl: resumeUrl ?? this.resumeUrl,
      reelUrl: reelUrl ?? this.reelUrl,
    );
  }
}