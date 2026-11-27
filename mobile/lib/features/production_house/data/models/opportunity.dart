enum OpportunityStatus {
  draft('Draft'),
  open('Open'),
  closed('Closed');

  final String label;
  const OpportunityStatus(this.label);
}

class Opportunity {
  final String id;
  final String? projectId;
  final String title;
  final String requirements;
  String get description => requirements;
  final DateTime deadline;
  final OpportunityStatus status;
  final String? productionHouseId;
  final String? roleType;
  final String? purpose;
  final int requiredMembers;
  final DateTime? workStartDate;
  final String? experience;
  final String? location;
  final String? compensation;
  final int applicationsCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Opportunity({
    required this.id,
    this.projectId,
    required this.title,
    required this.requirements,
    required this.deadline,
    required this.status,
    this.productionHouseId,
    this.roleType,
    this.purpose,
    this.requiredMembers = 1,
    this.workStartDate,
    this.experience,
    this.location,
    this.compensation,
    this.applicationsCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  static OpportunityStatus parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'open':
        return OpportunityStatus.open;
      case 'closed':
        return OpportunityStatus.closed;
      case 'draft':
      default:
        return OpportunityStatus.draft;
    }
  }

  static String toBackendStatus(OpportunityStatus status) {
    switch (status) {
      case OpportunityStatus.draft:
        return 'draft';
      case OpportunityStatus.open:
        return 'open';
      case OpportunityStatus.closed:
        return 'closed';
    }
  }

  factory Opportunity.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString() ?? '';
    final rawProjectId = json['project_id']?.toString();
    final title = json['title']?.toString() ?? 'Job Requirement';
    final requirements = json['requirements']?.toString() ?? '';

    DateTime deadline;
    if (json['deadline'] != null && json['deadline'].toString().isNotEmpty) {
      deadline = DateTime.tryParse(json['deadline'].toString()) ??
          DateTime.now().add(const Duration(days: 30));
    } else {
      deadline = DateTime.now().add(const Duration(days: 30));
    }

    final status = parseStatus(json['status']?.toString());

    DateTime? workStart;
    if (json['work_start_date'] != null && json['work_start_date'].toString().isNotEmpty) {
      workStart = DateTime.tryParse(json['work_start_date'].toString());
    }

    int reqMembers = 1;
    if (json['required_members'] != null) {
      reqMembers = int.tryParse(json['required_members'].toString()) ?? 1;
    }

    int appsCount = 0;
    if (json['applications_count'] != null) {
      appsCount = int.tryParse(json['applications_count'].toString()) ?? 0;
    }

    DateTime? createdAt;
    if (json['created_at'] != null && json['created_at'].toString().isNotEmpty) {
      createdAt = DateTime.tryParse(json['created_at'].toString());
    }

    DateTime? updatedAt;
    if (json['updated_at'] != null && json['updated_at'].toString().isNotEmpty) {
      updatedAt = DateTime.tryParse(json['updated_at'].toString());
    }

    return Opportunity(
      id: rawId,
      projectId: rawProjectId,
      title: title,
      requirements: requirements,
      deadline: deadline,
      status: status,
      productionHouseId: json['production_house_id']?.toString(),
      roleType: json['role_type']?.toString(),
      purpose: json['purpose']?.toString(),
      requiredMembers: reqMembers,
      workStartDate: workStart,
      experience: json['experience']?.toString(),
      location: json['location']?.toString(),
      compensation: json['compensation']?.toString(),
      applicationsCount: appsCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Opportunity copyWith({
    String? id,
    String? projectId,
    String? title,
    String? requirements,
    DateTime? deadline,
    OpportunityStatus? status,
    String? productionHouseId,
    String? roleType,
    String? purpose,
    int? requiredMembers,
    DateTime? workStartDate,
    String? experience,
    String? location,
    String? compensation,
    int? applicationsCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Opportunity(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      requirements: requirements ?? this.requirements,
      deadline: deadline ?? this.deadline,
      status: status ?? this.status,
      productionHouseId: productionHouseId ?? this.productionHouseId,
      roleType: roleType ?? this.roleType,
      purpose: purpose ?? this.purpose,
      requiredMembers: requiredMembers ?? this.requiredMembers,
      workStartDate: workStartDate ?? this.workStartDate,
      experience: experience ?? this.experience,
      location: location ?? this.location,
      compensation: compensation ?? this.compensation,
      applicationsCount: applicationsCount ?? this.applicationsCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}