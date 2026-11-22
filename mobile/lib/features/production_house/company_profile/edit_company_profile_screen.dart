import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cineconnect/features/production_house/data/models/company_profile.dart';
import 'company_profile_provider.dart';

class EditCompanyProfileScreen extends ConsumerWidget {
  const EditCompanyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(companyProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load your profile'),
              TextButton(
                onPressed: () => ref.invalidate(companyProfileProvider),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
        data: (profile) => _EditForm(profile: profile),
      ),
    );
  }
}

class _EditForm extends ConsumerStatefulWidget {
  final CompanyProfile profile;

  const _EditForm({required this.profile});

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.profile.companyName);
  late final _descriptionController =
      TextEditingController(text: widget.profile.description);
  late final _locationController =
      TextEditingController(text: widget.profile.location);
  late final _specializationController =
      TextEditingController(text: widget.profile.specialization);
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _specializationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(companyProfileProvider.notifier).save(
            companyName: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
            location: _locationController.text.trim(),
            specialization: _specializationController.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save your profile')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Production name'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter your company name'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'About / Description',
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Tell talent about your company'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Location'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter your location'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _specializationController,
                decoration: const InputDecoration(
                  labelText: 'Genres / Specialization',
                  helperText: 'Separate with commas, e.g. Thriller, Drama',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter at least one genre'
                    : null,
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
                    : const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}