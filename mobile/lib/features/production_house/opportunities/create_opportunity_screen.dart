import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cineconnect/core/network/api_client.dart';
import 'package:cineconnect/core/utils/formatters.dart';
import 'package:cineconnect/features/production_house/data/models/opportunity.dart';
import 'package:cineconnect/features/production_house/data/models/project.dart';
import 'package:cineconnect/shared/widgets/async_body.dart';
import 'package:cineconnect/shared/widgets/empty_state.dart';
import 'package:cineconnect/features/production_house/projects/projects_provider.dart';
import 'opportunities_provider.dart';

class CreateOpportunityScreen extends ConsumerStatefulWidget {
  /// null = create a new casting call, otherwise edit the one with this id.
  final String? opportunityId;

  const CreateOpportunityScreen({super.key, this.opportunityId});

  @override
  ConsumerState<CreateOpportunityScreen> createState() =>
      _CreateOpportunityScreenState();
}

class _CreateOpportunityScreenState
    extends ConsumerState<CreateOpportunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _requirementsController = TextEditingController();
  String? _projectId;
  DateTime? _deadline;
  bool _loading = false;
  Opportunity? _editing;

  bool get _isEdit => widget.opportunityId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final list = ref.read(opportunitiesProvider).valueOrNull ?? const <Opportunity>[];
      _editing = list.where((o) => o.id == widget.opportunityId).firstOrNull;
      final o = _editing;
      if (o != null) {
        _titleController.text = o.title;
        _requirementsController.text = o.requirements;
        _projectId = o.projectId;
        _deadline = o.deadline;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _requirementsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now(),
      // When editing, the saved deadline may already be in the past.
      firstDate: _isEdit ? DateTime(2020) : DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_deadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick an application deadline')),
      );
      return;
    }
    setState(() => _loading = true);
    final notifier = ref.read(opportunitiesProvider.notifier);
    try {
      if (_isEdit) {
        await notifier.edit(
          id: widget.opportunityId!,
          projectId: _projectId!,
          title: _titleController.text.trim(),
          requirements: _requirementsController.text.trim(),
          deadline: _deadline!,
        );
      } else {
        await notifier.add(
          projectId: _projectId!,
          title: _titleController.text.trim(),
          requirements: _requirementsController.text.trim(),
          deadline: _deadline!,
        );
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        final message = e is ApiException
            ? e.message
            : (_isEdit ? 'Could not save changes' : 'Could not create casting call');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? 'Edit casting call' : 'New casting call';

    if (_isEdit && _editing == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const EmptyState(
          message: 'Casting call not found',
          icon: Icons.search_off,
        ),
      );
    }

    final projectsAsync = ref.watch(projectsProvider);
    final d = _deadline;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: AsyncBody<List<Project>>(
        value: projectsAsync,
        errorMessage: 'Could not load projects',
        onRetry: () => ref.invalidate(projectsProvider),
        data: (projects) {
          if (projects.isEmpty) {
            return const EmptyState(
              message: 'Create a project first, then add casting calls to it.',
              icon: Icons.movie_creation_outlined,
            );
          }
          final selectedProjectValid = projects.any((p) => p.id == _projectId);
          final initialProject = selectedProjectValid ? _projectId : null;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: initialProject,
                      decoration: const InputDecoration(labelText: 'Project'),
                      items: [
                        for (final p in projects)
                          DropdownMenuItem(value: p.id, child: Text(p.title)),
                      ],
                      onChanged: (value) => setState(() => _projectId = value),
                      validator: (v) => v == null ? 'Choose a project' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Role / position title',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter a title'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _requirementsController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Requirements',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter the requirements'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.event),
                      label: Text(
                        d == null
                            ? 'Pick application deadline'
                            : 'Apply by ${formatDate(d)}',
                      ),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isEdit ? 'Save changes' : 'Save as draft'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}