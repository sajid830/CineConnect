import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/application.dart';
import '../../data/models/opportunity.dart';
import '../opportunities/opportunities_provider.dart';
import 'application_status_badge.dart';
import 'applications_provider.dart';

class ApplicationDetailScreen extends ConsumerStatefulWidget {
  final String applicationId;

  const ApplicationDetailScreen({super.key, required this.applicationId});

  @override
  ConsumerState<ApplicationDetailScreen> createState() =>
      _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState
    extends ConsumerState<ApplicationDetailScreen> {
  bool _busy = false;

  Future<void> _changeStatus(ApplicationStatus status) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(applicationsProvider.notifier)
          .setStatus(widget.applicationId, status);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update the application')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmReject(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject this application?'),
        content: Text('Are you sure you want to reject $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Reject',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _changeStatus(ApplicationStatus.rejected);
    }
  }

  List<Widget> _actions(JobApplication a) {
    switch (a.status) {
      case ApplicationStatus.received:
        return [
          ElevatedButton(
            onPressed:
                _busy ? null : () => _changeStatus(ApplicationStatus.underReview),
            child: const Text('Start review'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : () => _confirmReject(a.talent.fullName),
            child: const Text('Reject'),
          ),
        ];
      case ApplicationStatus.underReview:
        return [
          ElevatedButton(
            onPressed:
                _busy ? null : () => _changeStatus(ApplicationStatus.shortlisted),
            child: const Text('Shortlist'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : () => _confirmReject(a.talent.fullName),
            child: const Text('Reject'),
          ),
        ];
      case ApplicationStatus.shortlisted:
        return [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gold),
            ),
            child: const Text(
              'Shortlisted. Next step: contact the candidate and arrange an audition or interview.',
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Messaging arrives with the Chat module'),
                ),
              );
            },
            child: const Text('Contact candidate'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed:
                _busy ? null : () => _changeStatus(ApplicationStatus.underReview),
            child: const Text('Move back to review'),
          ),
        ];
      case ApplicationStatus.rejected:
        return [
          const Text(
            'This application was rejected.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed:
                _busy ? null : () => _changeStatus(ApplicationStatus.underReview),
            child: const Text('Move back to review'),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final applicationsAsync = ref.watch(applicationsProvider);
    final opportunities = ref.watch(opportunitiesProvider).maybeWhen(
          data: (list) => list,
          orElse: () => <Opportunity>[],
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Application')),
      body: applicationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load this application'),
              TextButton(
                onPressed: () => ref.invalidate(applicationsProvider),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
        data: (list) {
          final a =
              list.where((x) => x.id == widget.applicationId).firstOrNull;
          if (a == null) {
            return const Center(child: Text('Application not found'));
          }
          final t = a.talent;
          final d = a.appliedAt;
          final opportunityTitle = opportunities
                  .where((o) => o.id == a.opportunityId)
                  .map((o) => o.title)
                  .firstOrNull ??
              'Unknown casting call';

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.gold,
                        child: Text(
                          t.initials,
                          style: const TextStyle(
                            fontSize: 20,
                            color: AppColors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.fullName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${t.role} · ${t.location}',
                              style:
                                  const TextStyle(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => context.push('/talent/${t.id}'),
                      icon: const Icon(Icons.person_outline, size: 18),
                      label: const Text('View full profile'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          opportunityTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.gold,
                          ),
                        ),
                      ),
                      ApplicationStatusBadge(status: a.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Applied on ${d.day}/${d.month}/${d.year}',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Cover letter',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(a.coverLetter),
                  const SizedBox(height: 32),
                  ..._actions(a),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}