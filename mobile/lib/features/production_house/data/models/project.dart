enum ProjectStatus {
  upcoming('Upcoming'),
  ongoing('Ongoing'),
  completed('Completed');

  final String label;
  const ProjectStatus(this.label);
}

class Project {
  final String id;
  final String title;
  final String description;
  final ProjectStatus status;
  final DateTime startDate;
  final String? genre;
  final String? budget;
  final String? projectType;
  final String? productionHouseName;
  final String? productionHouseLogo;
  final int applicationsCount;
  final bool hasUserApplied;
  final String? applicationStatus;
  final DateTime? endDate;
  final String? productionHouseId;

  const Project({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.startDate,
    this.genre,
    this.budget,
    this.projectType,
    this.productionHouseName,
    this.productionHouseLogo,
    this.applicationsCount = 0,
    this.hasUserApplied = false,
    this.applicationStatus,
    this.endDate,
    this.productionHouseId,
  });

  static ProjectStatus parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
      case 'released':
        return ProjectStatus.completed;
      case 'ongoing':
      case 'production':
      case 'in_production':
      case 'filming':
      case 'post_production':
        return ProjectStatus.ongoing;
      case 'upcoming':
      case 'development':
      case 'pre_production':
      default:
        return ProjectStatus.upcoming;
    }
  }

  static String toBackendStatus(ProjectStatus status) {
    switch (status) {
      case ProjectStatus.upcoming:
        return 'development';
      case ProjectStatus.ongoing:
        return 'production';
      case ProjectStatus.completed:
        return 'completed';
    }
  }

  factory Project.fromJson(
    Map<String, dynamic> json, {
    bool? hasUserApplied,
    String? applicationStatus,
  }) {
    final rawId = json['id']?.toString() ?? '';
    final title = json['title']?.toString() ?? 'Untitled Project';
    final description = json['description']?.toString() ?? '';
    final status = parseStatus(json['status']?.toString());

    DateTime start;
    if (json['start_date'] != null && json['start_date'].toString().isNotEmpty) {
      start = DateTime.tryParse(json['start_date'].toString()) ?? DateTime.now();
    } else if (json['created_at'] != null && json['created_at'].toString().isNotEmpty) {
      start = DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now();
    } else {
      start = DateTime.now();
    }

    DateTime? end;
    if (json['end_date'] != null && json['end_date'].toString().isNotEmpty) {
      end = DateTime.tryParse(json['end_date'].toString());
    }

    return Project(
      id: rawId,
      title: title,
      description: description,
      status: status,
      startDate: start,
      genre: json['genre']?.toString(),
      budget: json['budget']?.toString(),
      projectType: json['project_type']?.toString(),
      productionHouseName: json['production_house_name']?.toString(),
      productionHouseLogo: json['production_house_logo']?.toString(),
      applicationsCount: (json['applications_count'] as num?)?.toInt() ?? 0,
      hasUserApplied: hasUserApplied ?? (json['has_user_applied'] == true),
      applicationStatus: applicationStatus ?? json['application_status']?.toString(),
      endDate: end,
      productionHouseId: json['production_house_id']?.toString(),
    );
  }

  Project copyWith({
    String? id,
    String? title,
    String? description,
    ProjectStatus? status,
    DateTime? startDate,
    String? genre,
    String? budget,
    String? projectType,
    String? productionHouseName,
    String? productionHouseLogo,
    int? applicationsCount,
    bool? hasUserApplied,
    String? applicationStatus,
    DateTime? endDate,
    String? productionHouseId,
  }) {
    return Project(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      genre: genre ?? this.genre,
      budget: budget ?? this.budget,
      projectType: projectType ?? this.projectType,
      productionHouseName: productionHouseName ?? this.productionHouseName,
      productionHouseLogo: productionHouseLogo ?? this.productionHouseLogo,
      applicationsCount: applicationsCount ?? this.applicationsCount,
      hasUserApplied: hasUserApplied ?? this.hasUserApplied,
      applicationStatus: applicationStatus ?? this.applicationStatus,
      endDate: endDate ?? this.endDate,
      productionHouseId: productionHouseId ?? this.productionHouseId,
    );
  }
}