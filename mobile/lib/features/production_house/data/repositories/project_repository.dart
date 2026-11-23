import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
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

class RemoteProjectRepository implements ProjectRepository {
  final ApiClient _client;

  RemoteProjectRepository({ApiClient? client}) : _client = client ?? ApiClient();

  @override
  Future<List<Project>> getProjects() async {
    try {
      final res = await _client.get(ApiEndpoints.myProjects);
      if (res is List) {
        return res.map((item) {
          if (item is Map) {
            return Project.fromJson(Map<String, dynamic>.from(item));
          }
          throw const FormatException('Expected project item to be a map');
        }).toList();
      }
      return [];
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        // If production house does not exist yet or no projects found
        return [];
      }
      rethrow;
    } catch (e) {
      throw ApiException(statusCode: 0, message: 'Failed to load projects: $e');
    }
  }

  @override
  Future<Project> createProject({
    required String title,
    required String description,
    required ProjectStatus status,
    required DateTime startDate,
  }) async {
    final startDateStr = startDate.toIso8601String().split('T').first;
    final body = {
      'title': title,
      'description': description,
      'status': Project.toBackendStatus(status),
      'start_date': startDateStr,
    };

    final res = await _client.post(ApiEndpoints.projectsCollection, body: body);
    if (res is Map) {
      return Project.fromJson(Map<String, dynamic>.from(res));
    }
    throw ApiException(
      statusCode: 500,
      message: 'Invalid response from server on project creation',
    );
  }

  @override
  Future<void> updateProject({
    required String id,
    required String title,
    required String description,
    required ProjectStatus status,
    required DateTime startDate,
  }) async {
    final startDateStr = startDate.toIso8601String().split('T').first;
    final body = {
      'title': title,
      'description': description,
      'status': Project.toBackendStatus(status),
      'start_date': startDateStr,
    };

    await _client.put(ApiEndpoints.projectDetails(id), body: body);
  }

  @override
  Future<void> deleteProject(String id) async {
    await _client.delete(ApiEndpoints.projectDetails(id));
  }

  /// Optional helper to fetch single project details by UUID
  Future<Project?> getProjectById(String id) async {
    try {
      final res = await _client.get(ApiEndpoints.projectDetails(id));
      if (res is Map) {
        return Project.fromJson(Map<String, dynamic>.from(res));
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  const useMock = bool.fromEnvironment('USE_MOCK_PH', defaultValue: true);
  return useMock ? MockProjectRepository() : RemoteProjectRepository();
});