import 'application.dart';

class DashboardSummary {
  final int activeProjects;
  final int openCastingCalls;
  final int newApplications;
  final int shortlisted;
  final List<JobApplication> recentApplications;

  const DashboardSummary({
    required this.activeProjects,
    required this.openCastingCalls,
    required this.newApplications,
    required this.shortlisted,
    required this.recentApplications,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      activeProjects: json['active_projects'] as int,
      openCastingCalls: json['open_casting_calls'] as int,
      newApplications: json['new_applications'] as int,
      shortlisted: json['shortlisted'] as int,
      recentApplications: [
        for (final a in json['recent_applications'] as List<dynamic>)
          JobApplication.fromJson(a as Map<String, dynamic>),
      ],
    );
  }
}