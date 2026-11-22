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
  final String opportunityId;
  final ApplicationStatus status;
  final String coverLetter;
  final DateTime appliedAt;
  final Talent talent;
  final String? resumeUrl;
  final String? reelUrl;

  const JobApplication({
    required this.id,
    required this.opportunityId,
    required this.status,
    required this.coverLetter,
    required this.appliedAt,
    required this.talent,
    this.resumeUrl,
    this.reelUrl,
  });

  factory JobApplication.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString() ?? '';
    final oppId = json['opportunity_id']?.toString() ?? '';
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
      status: status ?? this.status,
      coverLetter: coverLetter ?? this.coverLetter,
      appliedAt: appliedAt ?? this.appliedAt,
      talent: talent ?? this.talent,
      resumeUrl: resumeUrl ?? this.resumeUrl,
      reelUrl: reelUrl ?? this.reelUrl,
    );
  }
}