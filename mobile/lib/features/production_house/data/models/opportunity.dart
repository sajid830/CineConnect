enum OpportunityStatus {
  draft('Draft'),
  open('Open'),
  closed('Closed');

  final String label;
  const OpportunityStatus(this.label);
}

class Opportunity {
  final String id;
  final String projectId;
  final String title;
  final String requirements;
  final DateTime deadline;
  final OpportunityStatus status;

  const Opportunity({
    required this.id,
    required this.projectId,
    required this.title,
    required this.requirements,
    required this.deadline,
    required this.status,
  });

  factory Opportunity.fromJson(Map<String, dynamic> json) {
    return Opportunity(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      title: json['title'] as String,
      requirements: json['requirements'] as String,
      deadline: DateTime.parse(json['deadline'] as String),
      status: OpportunityStatus.values.byName(json['status'] as String),
    );
  }
}