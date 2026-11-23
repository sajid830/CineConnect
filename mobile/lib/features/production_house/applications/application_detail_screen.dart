import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cineconnect/app/theme.dart';
import 'package:cineconnect/core/network/api_client.dart';
import 'package:cineconnect/features/production_house/data/models/application.dart';
import 'package:cineconnect/features/production_house/data/models/opportunity.dart';
import 'package:cineconnect/features/production_house/data/repositories/application_repository.dart';
import 'package:cineconnect/features/production_house/opportunities/opportunities_provider.dart';
import 'application_status_badge.dart';
import 'applications_provider.dart';
import 'audition_video_player_dialog.dart';

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
  bool _loadingResume = false;
  bool _loadingReel = false;

  Future<void> _viewResume(JobApplication application) async {
    setState(() => _loadingResume = true);
    try {
      final downloadUrl = await ref
          .read(applicationRepositoryProvider)
          .getResumeDownloadUrl(application.id);

      final uri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not open external PDF viewer');
      }
    } catch (e) {
      if (mounted) {
        String message = 'Could not open resume.';
        if (e is ApiException) {
          if (e.statusCode == 404) {
            message = 'Resume file not found or has been removed.';
          } else if (e.statusCode == 403) {
            message = 'You do not have permission to access this resume.';
          } else {
            message = e.message;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF3B1212),
            content: Text(
              message,
              style: const TextStyle(color: Color(0xFFFF8B8B)),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingResume = false);
    }
  }

  Future<void> _watchAuditionReel(
    JobApplication application,
    String opportunityTitle,
  ) async {
    setState(() => _loadingReel = true);
    try {
      final downloadUrl = await ref
          .read(applicationRepositoryProvider)
          .getReelDownloadUrl(application.id);

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogCtx) => AuditionVideoPlayerDialog(
          downloadUrl: downloadUrl,
          candidateName: application.talent.fullName,
          projectTitle: opportunityTitle,
          onRefreshUrl: () => ref
              .read(applicationRepositoryProvider)
              .getReelDownloadUrl(application.id),
        ),
      );
    } catch (e) {
      if (mounted) {
        String message = 'Could not load audition video.';
        if (e is ApiException) {
          if (e.statusCode == 404) {
            message = 'Audition video not found or has been removed.';
          } else if (e.statusCode == 403) {
            message = 'You do not have permission to access this audition video.';
          } else {
            message = e.message;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF3B1212),
            content: Text(
              message,
              style: const TextStyle(color: Color(0xFFFF8B8B)),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingReel = false);
    }
  }

  Future<void> _changeStatus(ApplicationStatus status) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(applicationsProvider.notifier)
          .setStatus(widget.applicationId, status);
    } catch (e) {
      if (mounted) {
        final message = e is ApiException
            ? e.message
            : 'Could not update the application';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
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
            onPressed:
                _busy ? null : () => _changeStatus(ApplicationStatus.accepted),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Accept candidate'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
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
      case ApplicationStatus.accepted:
        return [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success),
            ),
            child: const Text(
              'Candidate accepted for this role. Contracting and onboarding underway.',
            ),
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
                      onPressed: () => context.push('/talent-profile/${t.id}'),
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

                  // Audition Media Attachments
                  if (a.reelUrl != null || a.resumeUrl != null) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Audition Attachments',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    if (a.reelUrl != null) ...[
                      InkWell(
                        onTap: (_loadingReel || _busy)
                            ? null
                            : () => _watchAuditionReel(a, opportunityTitle),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.gold, width: 1.2),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: AppColors.gold,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'Audition Self-Tape Video',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Watch candidate audition tape with in-app playback',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_loadingReel)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.gold,
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.gold,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (a.resumeUrl != null) ...[
                      InkWell(
                        onTap: (_loadingResume || _busy)
                            ? null
                            : () => _viewResume(a),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.picture_as_pdf_rounded,
                                  color: AppColors.gold,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'Resume / CV (PDF)',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Open authorized PDF in document viewer',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_loadingResume)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.gold,
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.open_in_new_rounded,
                                  color: AppColors.textMuted,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
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