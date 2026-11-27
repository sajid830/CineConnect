import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cineconnect/core/network/api_client.dart';
import 'package:cineconnect/core/utils/formatters.dart';
import 'package:cineconnect/features/production_house/data/models/opportunity.dart';
import 'package:cineconnect/features/production_house/data/models/project.dart';
import 'package:cineconnect/shared/widgets/empty_state.dart';
import 'package:cineconnect/features/production_house/projects/projects_provider.dart';
import 'package:cineconnect/features/production_house/applications/applications_provider.dart';
import 'opportunities_provider.dart';

class CreateOpportunityScreen extends ConsumerStatefulWidget {
  /// null = create a new job, otherwise edit the one with this id.
  final String? opportunityId;

  const CreateOpportunityScreen({super.key, this.opportunityId});

  @override
  ConsumerState<CreateOpportunityScreen> createState() =>
      _CreateOpportunityScreenState();
}

class _CreateOpportunityScreenState
    extends ConsumerState<CreateOpportunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customRoleController = TextEditingController();
  final _customPurposeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _experienceController = TextEditingController();
  final _requiredMembersController = TextEditingController(text: '1');

  static const List<String> _roleOptions = [
    'Others',
    'Actor',
    'Cameraman',
    'Choreographer',
    'Fight Master',
    'Stuntman',
    'Comedian',
    'Technician',
    'Director',
    'Producer',
    'Heroine',
  ];

  static const List<String> _purposeOptions = [
    'Others',
    'Movie',
    'Web Series',
    'Serial',
    'Advertisement',
    'Short Film',
    'Music Video',
    'Documentary',
  ];

  String _selectedRole = 'Actor';
  String _selectedPurpose = 'Movie';
  String? _projectId;
  DateTime? _workStartDate;
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
        _descriptionController.text = o.requirements;
        _experienceController.text = o.experience ?? '';
        _projectId = o.projectId;
        _deadline = o.deadline;
        _workStartDate = o.workStartDate;
        _requiredMembersController.text = o.requiredMembers.toString();

        final r = o.roleType ?? o.title;
        if (_roleOptions.contains(r) && r != 'Others') {
          _selectedRole = r;
        } else {
          _selectedRole = 'Others';
          _customRoleController.text = r == 'Others' ? '' : r;
        }

        final p = o.purpose;
        if (p != null && _purposeOptions.contains(p) && p != 'Others') {
          _selectedPurpose = p;
        } else if (p != null && p.isNotEmpty) {
          _selectedPurpose = 'Others';
          _customPurposeController.text = p;
        }
      }
    }
  }

  @override
  void dispose() {
    _customRoleController.dispose();
    _customPurposeController.dispose();
    _descriptionController.dispose();
    _experienceController.dispose();
    _requiredMembersController.dispose();
    super.dispose();
  }

  Future<void> _pickWorkStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _workStartDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: _isEdit ? DateTime(2020) : DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _workStartDate = picked);
  }

  String _resolveRole() {
    if (_selectedRole == 'Others') {
      final custom = _customRoleController.text.trim();
      return custom.isNotEmpty ? custom : 'Others';
    }
    return _selectedRole;
  }

  String _resolvePurpose() {
    if (_selectedPurpose == 'Others') {
      final custom = _customPurposeController.text.trim();
      return custom.isNotEmpty ? custom : 'Others';
    }
    return _selectedPurpose;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_workStartDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the expected work start date')),
      );
      return;
    }

    final members = int.tryParse(_requiredMembersController.text.trim());
    if (members == null || members <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid positive number of members (at least 1)')),
      );
      return;
    }

    setState(() => _loading = true);
    final notifier = ref.read(opportunitiesProvider.notifier);
    final resolvedRole = _resolveRole();
    final resolvedPurpose = _resolvePurpose();
    final deadlineDate = _deadline ?? _workStartDate!.add(const Duration(days: 14));

    try {
      if (_isEdit) {
        await notifier.edit(
          id: widget.opportunityId!,
          projectId: _projectId,
          title: resolvedRole,
          roleType: resolvedRole,
          purpose: resolvedPurpose,
          requiredMembers: members,
          workStartDate: _workStartDate,
          experience: _experienceController.text.trim(),
          requirements: _descriptionController.text.trim(),
          deadline: deadlineDate,
        );
      } else {
        await notifier.add(
          projectId: _projectId,
          title: resolvedRole,
          roleType: resolvedRole,
          purpose: resolvedPurpose,
          requiredMembers: members,
          workStartDate: _workStartDate,
          experience: _experienceController.text.trim(),
          requirements: _descriptionController.text.trim(),
          deadline: deadlineDate,
        );
      }
      ref.invalidate(opportunitiesProvider);
      ref.invalidate(applicationsProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        final message = e is ApiException
            ? e.message
            : (_isEdit ? 'Could not save changes' : 'Could not publish job');
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
    final title = _isEdit ? 'Edit Job' : 'Create New Job';

    if (_isEdit && _editing == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const EmptyState(
          message: 'Job not found',
          icon: Icons.search_off,
        ),
      );
    }

    final projects = ref.watch(projectsProvider).valueOrNull ?? const <Project>[];
    final selectedProjectValid = projects.any((p) => p.id == _projectId);
    final initialProject = selectedProjectValid ? _projectId : null;
    final wsd = _workStartDate;

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
                // 1. Role Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedRole,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: [
                    for (final r in _roleOptions)
                      DropdownMenuItem(value: r, child: Text(r)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedRole = value);
                  },
                ),
                if (_selectedRole == 'Others') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _customRoleController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Enter Role',
                      hintText: 'e.g. Script Supervisor, Colorist',
                    ),
                    validator: (v) {
                      if (_selectedRole == 'Others' && (v == null || v.trim().isEmpty)) {
                        return 'Please enter a custom role';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),

                // 2. Purpose Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedPurpose,
                  decoration: const InputDecoration(labelText: 'Purpose'),
                  items: [
                    for (final p in _purposeOptions)
                      DropdownMenuItem(value: p, child: Text(p)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedPurpose = value);
                  },
                ),
                if (_selectedPurpose == 'Others') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _customPurposeController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Enter Purpose',
                      hintText: 'e.g. Corporate Film, Feature Doc',
                    ),
                    validator: (v) {
                      if (_selectedPurpose == 'Others' && (v == null || v.trim().isEmpty)) {
                        return 'Please enter custom purpose';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),

                // 3. Job Description
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Job Description',
                    hintText: 'Explain responsibilities of the role, required skills, experience, and expectations from applicants.',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter job description'
                      : null,
                ),
                const SizedBox(height: 16),

                // 4. Number of Required Members
                TextFormField(
                  controller: _requiredMembersController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Number of Required Members',
                    hintText: 'e.g. 1, 2, 5',
                    prefixIcon: Icon(Icons.people_outline),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter number of members required';
                    final n = int.tryParse(v.trim());
                    if (n == null || n <= 0) return 'Must be a positive number (1 or more)';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 5. Experience
                TextFormField(
                  controller: _experienceController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Experience',
                    hintText: 'e.g. 2 years, 3 years, Fresher',
                    prefixIcon: Icon(Icons.work_history_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                // 5. Work Start Date
                OutlinedButton.icon(
                  onPressed: _pickWorkStartDate,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    wsd == null
                        ? 'Select Work Start Date'
                        : 'Work Starts ${formatDate(wsd)}',
                  ),
                ),
                const SizedBox(height: 16),

                // Optional parent project
                if (projects.isNotEmpty)
                  DropdownButtonFormField<String?>(
                    initialValue: initialProject,
                    decoration: const InputDecoration(
                      labelText: 'Parent Project (Optional)',
                      helperText: 'Attach this job to an existing production project, if applicable.',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Standalone / Independent Job'),
                      ),
                      for (final p in projects)
                        DropdownMenuItem<String?>(
                          value: p.id,
                          child: Text(p.title),
                        ),
                    ],
                    onChanged: (value) => setState(() => _projectId = value),
                  ),
                const SizedBox(height: 28),

                // 6. Submit Button
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEdit ? 'Save Changes' : 'Publish Job'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}