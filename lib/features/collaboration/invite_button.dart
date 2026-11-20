import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/project.dart';
import '../../data/models/talent.dart';
import '../../data/repositories/collaboration_repository.dart';
import '../projects/projects_provider.dart';
import 'collaborations_provider.dart';

class InviteButton extends ConsumerStatefulWidget {
  final Talent talent;

  const InviteButton({super.key, required this.talent});

  @override
  ConsumerState<InviteButton> createState() => _InviteButtonState();
}

class _InviteButtonState extends ConsumerState<InviteButton> {
  bool _busy = false;

  void _say(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _invite() async {
    setState(() => _busy = true);
    try {
      final projects = await ref.read(projectsProvider.future);
      final eligible =
          projects.where((p) => p.status != ProjectStatus.completed).toList();
      if (!mounted) return;
      if (eligible.isEmpty) {
        _say('Create an upcoming or ongoing project first');
        return;
      }

      final chosen = await showModalBottomSheet<Project>(
        context: context,
        builder: (_) => _ProjectPickerSheet(
          projects: eligible,
          talentName: widget.talent.fullName,
        ),
      );
      if (chosen == null || !mounted) return;

      await ref.read(collaborationsProvider.notifier).invite(
            projectId: chosen.id,
            talentId: widget.talent.id,
          );
      if (!mounted) return;
      _say('Invitation sent to ${widget.talent.fullName} for ${chosen.title}');
    } on AlreadyInvitedException {
      if (mounted) _say('${widget.talent.fullName} is already on that project');
    } catch (e) {
      if (mounted) _say('Could not send the invitation');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _busy ? null : _invite,
      child: _busy
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Invite to collaborate'),
    );
  }
}

class _ProjectPickerSheet extends StatelessWidget {
  final List<Project> projects;
  final String talentName;

  const _ProjectPickerSheet({
    required this.projects,
    required this.talentName,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invite $talentName to...',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in projects)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(p.title),
                      subtitle: Text(
                        p.status.label,
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).pop(p),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}