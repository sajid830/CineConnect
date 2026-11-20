import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';

abstract class ProjectRepository {
  Future<List<Project>> getProjects();

  Future<Project> createProject({
    required String title,
    required String description,
    required ProjectStatus status,
    required DateTime startDate,
  });

  Future<void> updateProject({
    required String id,
    required String title,
    required String description,
    required ProjectStatus status,
    required DateTime startDate,
  });

  Future<void> deleteProject(String id);
}

class MockProjectRepository implements ProjectRepository {
  final List<Project> _projects = [
    Project(
      id: 'p1',
      title: 'Midnight Express',
      description: 'A thriller shot across three cities. Casting leads and crew.',
      status: ProjectStatus.ongoing,
      startDate: DateTime(2026, 9, 1),
    ),
    Project(
      id: 'p2',
      title: 'Monsoon Diaries',
      description: 'A romantic drama set in the Western Ghats.',
      status: ProjectStatus.upcoming,
      startDate: DateTime(2027, 1, 15),
    ),
    Project(
      id: 'p3',
      title: 'The Last Reel',
      description: 'A short film about an old projectionist.',
      status: ProjectStatus.completed,
      startDate: DateTime(2026, 3, 10),
    ),
  ];

  @override
  Future<List<Project>> getProjects() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return List.of(_projects);
  }

  @override
  Future<Project> createProject({
    required String title,
    required String description,
    required ProjectStatus status,
    required DateTime startDate,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final project = Project(
      id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: description,
      status: status,
      startDate: startDate,
    );
    _projects.insert(0, project);
    return project;
  }

  @override
  Future<void> updateProject({
    required String id,
    required String title,
    required String description,
    required ProjectStatus status,
    required DateTime startDate,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));
    final index = _projects.indexWhere((p) => p.id == id);
    if (index == -1) return;
    _projects[index] = Project(
      id: id,
      title: title,
      description: description,
      status: status,
      startDate: startDate,
    );
  }

  @override
  Future<void> deleteProject(String id) async {
    await Future.delayed(const Duration(milliseconds: 600));
    _projects.removeWhere((p) => p.id == id);
  }
}

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return MockProjectRepository();
});