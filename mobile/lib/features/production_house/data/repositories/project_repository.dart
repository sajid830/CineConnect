import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/project.dart';

abstract class ProjectRepository {
  Future<List<Project>> getProjects();

  Future<Project> createProject({
    required String title,
    String? projectType,
    required String description,
    required ProjectStatus status,
    required DateTime startDate,
    String? budget,
  });

  Future<void> updateProject({
    required String id,
    required String title,
    String? projectType,
    required String description,
    required ProjectStatus status,
    required DateTime startDate,
    String? budget,
  });

  Future<void> deleteProject(String id);
}

class MockProjectRepository implements ProjectRepository {
  final List<Project> _projects = [];

  @override
  Future<List<Project>> getProjects() async {
    return List.of(_projects);
  }

  @override
  Future<Project> createProject({
    required String title,
    String? projectType,
    required String description,
    required ProjectStatus status,
    required DateTime startDate,
    String? budget,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final project = Project(
      id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      genre: projectType,
      description: description,
      status: status,
      startDate: startDate,
      budget: budget,
    );
    _projects.insert(0, project);
    return project;
  }

  @override
  Future<void> updateProject({
    required String id,
    required String title,
    String? projectType,
    required String description,
    required ProjectStatus status,
    required DateTime startDate,
    String? budget,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));
    final index = _projects.indexWhere((p) => p.id == id);
    if (index == -1) return;
    _projects[index] = Project(
      id: id,
      title: title,
      genre: projectType ?? _projects[index].genre,
      description: description,
      status: status,
      startDate: startDate,
      budget: budget ?? _projects[index].budget,
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
    String? projectType,
    required String description,
    required ProjectStatus status,
    required DateTime startDate,
    String? budget,
  }) async {
    final startDateStr = startDate.toIso8601String().split('T').first;
    final body = {
      'title': title,
      if (projectType != null && projectType.isNotEmpty) 'project_type': projectType,
      if (projectType != null && projectType.isNotEmpty) 'genre': projectType,
      'description': description,
      'status': Project.toBackendStatus(status),
      'start_date': startDateStr,
      if (budget != null && budget.isNotEmpty) 'budget': budget,
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
    String? projectType,
    required String description,
    required ProjectStatus status,
    required DateTime startDate,
    String? budget,
  }) async {
    final startDateStr = startDate.toIso8601String().split('T').first;
    final body = {
      'title': title,
      if (projectType != null && projectType.isNotEmpty) 'project_type': projectType,
      if (projectType != null && projectType.isNotEmpty) 'genre': projectType,
      'description': description,
      'status': Project.toBackendStatus(status),
      'start_date': startDateStr,
      if (budget != null && budget.isNotEmpty) 'budget': budget,
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
  return RemoteProjectRepository();
});