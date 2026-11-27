import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cineconnect/core/network/api_client.dart';
import 'package:cineconnect/core/utils/formatters.dart';
import 'package:cineconnect/features/production_house/data/models/project.dart';
import 'package:cineconnect/shared/widgets/empty_state.dart';
import 'package:cineconnect/features/production_house/applications/applications_provider.dart';
import 'projects_provider.dart';

class CreateProjectScreen extends ConsumerStatefulWidget {
  /// null = create a new project, otherwise edit the project with this id.
  final String? projectId;

  const CreateProjectScreen({super.key, this.projectId});

  @override
  ConsumerState<CreateProjectScreen> createState() =>
      _CreateProjectScreenState();
}

class _CreateProjectScreenState extends ConsumerState<CreateProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _customTypeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();

  static const List<String> _projectTypeOptions = [
    'Others',
    'Movie',
    'Web Series',
    'Serial',
  ];

  String _selectedType = 'Movie';
  ProjectStatus _status = ProjectStatus.upcoming;
  DateTime? _startDate;
  bool _loading = false;
  Project? _editing;

  bool get _isEdit => widget.projectId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final list = ref.read(projectsProvider).valueOrNull ?? const <Project>[];
      _editing = list.where((p) => p.id == widget.projectId).firstOrNull;
      final p = _editing;
      if (p != null) {
        _titleController.text = p.title;
        _descriptionController.text = p.description;
        _status = p.status;
        _startDate = p.startDate;
        if (p.budget != null) {
          _budgetController.text = p.budget!;
        }
        final existingType = p.genre;
        if (existingType != null && existingType.isNotEmpty) {
          if (_projectTypeOptions.contains(existingType) && existingType != 'Others') {
            _selectedType = existingType;
          } else {
            _selectedType = 'Others';
            _customTypeController.text = existingType == 'Others' ? '' : existingType;
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _customTypeController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  String _resolveProjectType() {
    if (_selectedType == 'Others') {
      final custom = _customTypeController.text.trim();
      return custom.isNotEmpty ? custom : 'Others';
    }
    return _selectedType;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a start date')),
      );
      return;
    }
    setState(() => _loading = true);
    final notifier = ref.read(projectsProvider.notifier);
    final resolvedType = _resolveProjectType();
    final budgetVal = _budgetController.text.trim();

    try {
      if (_isEdit) {
        await notifier.edit(
          id: widget.projectId!,
          title: _titleController.text.trim(),
          projectType: resolvedType,
          description: _descriptionController.text.trim(),
          status: _status,
          startDate: _startDate!,
          budget: budgetVal.isNotEmpty ? budgetVal : null,
        );
      } else {
        await notifier.add(
          title: _titleController.text.trim(),
          projectType: resolvedType,
          description: _descriptionController.text.trim(),
          status: _status,
          startDate: _startDate!,
          budget: budgetVal.isNotEmpty ? budgetVal : null,
        );
      }
      ref.invalidate(projectsProvider);
      ref.invalidate(applicationsProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException && e.message.isNotEmpty
                  ? e.message
                  : (_isEdit ? 'Could not save changes' : 'Could not create project'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? 'Edit project' : 'New project';

    if (_isEdit && _editing == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const EmptyState(
          message: 'Project not found',
          icon: Icons.search_off,
        ),
      );
    }

    final d = _startDate;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Project title'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter a title'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  decoration: const InputDecoration(labelText: 'Project Type'),
                  items: [
                    for (final t in _projectTypeOptions)
                      DropdownMenuItem(value: t, child: Text(t)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedType = value);
                  },
                ),
                if (_selectedType == 'Others') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _customTypeController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Enter Project Type',
                      hintText: 'e.g. Docudrama, Animation Film',
                    ),
                    validator: (v) {
                      if (_selectedType == 'Others' && (v == null || v.trim().isEmpty)) {
                        return 'Please enter custom project type';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Project Description',
                    hintText: 'Describe your production and the crew members you are looking for, such as actors, cameramen, directors, choreographers, stuntmen, fight masters, technicians and other production team members.',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter project description'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ProjectStatus>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    for (final s in ProjectStatus.values)
                      DropdownMenuItem(value: s, child: Text(s.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _status = value);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _budgetController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Project Budget',
                    hintText: 'Enter Project Budget (e.g. ₹100 Crores, ₹50 Lakhs)',
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    d == null
                      ? 'Pick start date'
                      : 'Starts ${formatDate(d)}',
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
                      : Text(_isEdit ? 'Save changes' : 'Publish Project'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}