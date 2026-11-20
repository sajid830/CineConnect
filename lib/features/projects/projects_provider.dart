import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/project.dart';
import '../../data/repositories/project_repository.dart';

class ProjectsNotifier extends AsyncNotifier<List<Project>> {
  @override
  Future<List<Project>> build() {
    return ref.read(projectRepositoryProvider).getProjects();
  }

  Future<void> add({
    required String title,
    required String description,
    required ProjectStatus status,
    required DateTime startDate,
  }) async {
    await ref.read(projectRepositoryProvider).createProject(
          title: title,
          description: description,
          status: status,
          startDate: startDate,
        );
    ref.invalidateSelf();
    await future;
  }

  Future<void> edit({
    required String id,
    required String title,
    required String description,
    required ProjectStatus status,
    required DateTime startDate,
  }) async {
    await ref.read(projectRepositoryProvider).updateProject(
          id: id,
          title: title,
          description: description,
          status: status,
          startDate: startDate,
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