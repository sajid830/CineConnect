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

  const Project({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.startDate,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      status: ProjectStatus.values.byName(json['status'] as String),
      startDate: DateTime.parse(json['start_date'] as String),
    );
  }
}