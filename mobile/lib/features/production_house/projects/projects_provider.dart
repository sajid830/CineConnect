import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cineconnect/features/production_house/data/models/project.dart';
import 'package:cineconnect/features/production_house/data/repositories/project_repository.dart';

class ProjectsNotifier extends AsyncNotifier<List<Project>> {
  @override
  Future<List<Project>> build() {
    return ref.read(projectRepositoryProvider).getProjects();
  }

  Future<void> add({
    required String title,
    String? projectType,
    required String description,
    required ProjectStatus status,
    required DateTime startDate,
    String? budget,
  }) async {
    await ref.read(projectRepositoryProvider).createProject(
          title: title,
          projectType: projectType,
          description: description,
          status: status,
          startDate: startDate,
          budget: budget,
        );
    ref.invalidateSelf();
    await future;
  }

  Future<void> edit({
    required String id,
    required String title,
    String? projectType,
    required String description,
    required ProjectStatus status,
    required DateTime startDate,
    String? budget,
  }) async {
    await ref.read(projectRepositoryProvider).updateProject(
          id: id,
          title: title,
          projectType: projectType,
          description: description,
          status: status,
          startDate: startDate,
          budget: budget,
        );
    ref.invalidateSelf();
    await future;
  }

  Future<void> remove(String id) async {
    await ref.read(projectRepositoryProvider).deleteProject(id);
    ref.invalidateSelf();
    await future;
  }
}

final projectsProvider =
    AsyncNotifierProvider<ProjectsNotifier, List<Project>>(ProjectsNotifier.new);