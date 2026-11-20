import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/project.dart';
import '../../shared/widgets/empty_state.dart';
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
  final _descriptionController = TextEditingController();
  ProjectStatus _status = ProjectStatus.upcoming;
  DateTime? _startDate;
  bool _loading = false;
  Project? _editing;

  bool get _isEdit => widget.projectId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final list = ref.read(projectsProvider).value ?? const <Project>[];
      _editing = list.where((p) => p.id == widget.projectId).firstOrNull;
      final p = _editing;
      if (p != null) {
        _titleController.text = p.title;
        _descriptionController.text = p.description;
        _status = p.status;
        _startDate = p.startDate;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
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
    try {
      if (_isEdit) {
        await notifier.edit(
          id: widget.projectId!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          status: _status,
          startDate: _startDate!,
        );
      } else {
        await notifier.add(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          status: _status,
          startDate: _startDate!,
        );
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEdit ? 'Could not save changes' : 'Could not create project',
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
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Description'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter a description'
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
                      : Text(_isEdit ? 'Save changes' : 'Create project'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}