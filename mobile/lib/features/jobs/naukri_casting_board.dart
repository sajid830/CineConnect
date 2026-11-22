import 'package:flutter/material.dart';
import 'package:cineconnect/app/theme.dart';
import '../../core/models/craft_models.dart';
import '../../core/state/app_state.dart';

class NaukriCastingBoard extends StatefulWidget {
  final CineAppState appState;

  const NaukriCastingBoard({super.key, required this.appState});

  @override
  State<NaukriCastingBoard> createState() => _NaukriCastingBoardState();
}

class _NaukriCastingBoardState extends State<NaukriCastingBoard> {
  int _activeSubTab = 0; // 0: Suggested for You, 1: Application Status
  String _selectedCraftFilter = 'All Crafts';

  void _showSelfTapeSubmissionDialog(ProductionJobBrief job) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13141C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: CineColors.gold, width: 1.2),
        ),
        title: Row(
          children: [
            const Icon(Icons.video_call_rounded, color: CineColors.gold, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Submit Audition: ${job.projectTitle}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Studio: ${job.studioName} • ${job.councilId}',
                style: const TextStyle(fontSize: 11.5, color: CineColors.goldLight)),
            const SizedBox(height: 12),
            const Text('Formatted 12pt Courier Screenplay Sides:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CineColors.textMuted)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CineColors.border),
              ),
              child: Text(
                job.screenplaySides,
                style: const TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 10.5,
                  color: Color(0xFFE2E2E8),
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CineColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.cloud_upload_outlined, color: CineColors.gold, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Attach Uncompressed Self-Tape (ProRes / MP4 1080p)',
                      style: TextStyle(fontSize: 11, color: CineColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: CineColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              widget.appState.applyToJob(job.id);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: CineColors.surfaceElevated,
                  content: Text(
                    'Application & Self-Tape Submitted to ${job.studioName}! Status: Under Director Review',
                    style: const TextStyle(color: CineColors.gold),
                  ),
                ),
              );
            },
            child: const Text('Submit 1-Tap Application'),
          ),
        ],
      ),
    );
  }

  void _showSidesPreviewDialog(ProductionJobBrief job) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13141C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: CineColors.gold, width: 1.2),
        ),
        title: Row(
          children: [
            const Icon(Icons.description_outlined, color: CineColors.gold, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Screenplay Sides: ${job.projectTitle}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: CineColors.border),
          ),
          child: Text(
            job.screenplaySides,
            style: const TextStyle(
              fontFamily: 'Courier',
              fontSize: 11,
              color: Color(0xFFE2E2E8),
              height: 1.45,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: CineColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showSelfTapeSubmissionDialog(job);
            },
            child: const Text('Apply with Self-Tape'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.submitted:
        return _statusPill('SUBMITTED', Colors.blue);
      case ApplicationStatus.underDirectorReview:
        return _statusPill('UNDER DIRECTOR REVIEW', CineColors.warning);
      case ApplicationStatus.shortlisted:
        return _statusPill('SHORTLISTED', CineColors.gold);
      case ApplicationStatus.callSheetHold:
        return _statusPill('CALL-SHEET HOLD', const Color(0xFF00E5FF));
      case ApplicationStatus.booked:
        return _statusPill('BOOKED / CONTRACTED', CineColors.success);
    }
  }

  Widget _statusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appliedJobs = widget.appState.jobBriefs.where((j) => j.hasUserApplied).toList();
    final suggestedJobs = [...widget.appState.jobBriefs]..sort(
        (a, b) => widget.appState
            .calculateSkillMatch(b.requiredSkills)
            .compareTo(widget.appState.calculateSkillMatch(a.requiredSkills)),
      );

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 10, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Naukri Summary Banner
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  CineColors.surfaceElevated,
                  Color(0xFF13141C),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CineColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.verified_rounded, size: 16, color: CineColors.gold),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Cinema Casting & Crew Calls',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: CineColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: CineColors.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PAN-INDIA BRIEFS',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: CineColors.gold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    const Expanded(
                      child: _StatBlock(title: '34', subtitle: 'Director Profile Views'),
                    ),
                    Expanded(
                      child: _StatBlock(title: '${appliedJobs.length}', subtitle: 'Active Auditions'),
                    ),
                    const Expanded(
                      child: _StatBlock(title: '96%', subtitle: 'Top Skill Match'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Sub-Tab Segment (Open Calls vs My Auditions Tracker)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: CineColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: CineColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _activeSubTab = 0),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _activeSubTab == 0 ? CineColors.gold.withValues(alpha: 0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _activeSubTab == 0 ? CineColors.gold : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 14,
                            color: _activeSubTab == 0 ? CineColors.gold : CineColors.textMuted,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Suggested for You',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: _activeSubTab == 0 ? FontWeight.bold : FontWeight.normal,
                                color: _activeSubTab == 0 ? CineColors.gold : CineColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _activeSubTab = 1),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _activeSubTab == 1 ? CineColors.gold.withValues(alpha: 0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _activeSubTab == 1 ? CineColors.gold : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.assignment_turned_in_outlined,
                            size: 14,
                            color: _activeSubTab == 1 ? CineColors.gold : CineColors.textMuted,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Application Status (${appliedJobs.length})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: _activeSubTab == 1 ? FontWeight.bold : FontWeight.normal,
                                color: _activeSubTab == 1 ? CineColors.gold : CineColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (_activeSubTab == 0) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  const Icon(Icons.tips_and_updates_outlined, size: 16, color: CineColors.gold),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Recommended jobs based on your profile',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: CineColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${suggestedJobs.length} jobs',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: CineColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),

            // Filter by Craft Dropdown
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: CineColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: CineColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCraftFilter,
                    dropdownColor: CineColors.surfaceElevated,
                    isExpanded: true,
                    items: ['All Crafts', 'Cinematography / DOP', 'Action & Stunt Director', 'Sound Design & Atmos Mix']
                        .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12))))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedCraftFilter = v);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Open Job Listings
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: suggestedJobs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final job = suggestedJobs[index];
                final matchPercent = widget.appState.calculateSkillMatch(job.requiredSkills).round();

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: CineColors.surfaceCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: matchPercent >= 80 ? CineColors.gold.withValues(alpha: 0.5) : CineColors.border,
                      width: matchPercent >= 80 ? 1.2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Studio & Match %
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: CineColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: CineColors.border),
                            ),
                            child: Center(
                              child: Text(
                                job.studioBannerLogo,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: CineColors.gold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  job.projectTitle,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: CineColors.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${job.studioName} • ${job.councilId}',
                                  style: const TextStyle(fontSize: 11, color: CineColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          // Match % Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: matchPercent >= 75
                                  ? CineColors.success.withValues(alpha: 0.18)
                                  : CineColors.warning.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: matchPercent >= 75 ? CineColors.success : CineColors.warning,
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              '$matchPercent% MATCH',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: matchPercent >= 75 ? CineColors.success : CineColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Craft & Location
                      Row(
                        children: [
                          const Icon(Icons.camera_alt_outlined, size: 14, color: CineColors.gold),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              job.targetCraft,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.location_on_outlined, size: 14, color: CineColors.textMuted),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              job.hubLocation,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11.5, color: CineColors.textMuted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Shoot Window & Compensation
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 13, color: CineColors.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              job.shootWindow,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: CineColors.textMuted),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            job.compensation,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CineColors.gold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Skill Match Chips
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: job.requiredSkills.map((skill) {
                          final hasSkill = widget.appState.userSkills.contains(skill);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: hasSkill ? const Color(0xFF0F291E) : CineColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: hasSkill ? CineColors.success : CineColors.border,
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  hasSkill ? Icons.check : Icons.close,
                                  size: 10,
                                  color: hasSkill ? CineColors.success : CineColors.textMuted,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  skill,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: hasSkill ? FontWeight.bold : FontWeight.normal,
                                    color: hasSkill ? CineColors.success : CineColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),

                      // Action Buttons
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () => _showSidesPreviewDialog(job),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: const Text('Read Sides', style: TextStyle(fontSize: 11)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _showSelfTapeSubmissionDialog(job),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              child: Text(
                                job.hasUserApplied ? '✓ Audition Submitted' : '1-Tap Self-Tape Apply',
                                style: const TextStyle(fontSize: 11.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ] else ...[
            // Application Status Tracker Tab
            if (appliedJobs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.assignment_outlined, size: 44, color: CineColors.textMuted),
                      SizedBox(height: 10),
                      Text(
                        'No applications yet',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: CineColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Apply from Suggested for You to track status here.',
                        style: TextStyle(fontSize: 11.5, color: CineColors.textMuted),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: appliedJobs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final job = appliedJobs[index];

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: CineColors.surfaceCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: CineColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(job.projectTitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          _buildStatusBadge(job.applicationStatus),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${job.studioName} • Role: ${job.targetCraft}',
                          style: const TextStyle(fontSize: 11.5, color: CineColors.goldLight)),
                      const SizedBox(height: 6),
                      Text('Shoot Window: ${job.shootWindow}', style: const TextStyle(fontSize: 11, color: CineColors.textMuted)),
                      const SizedBox(height: 10),

                      // Visual Step Progression Tracker
                      Row(
                        children: [
                          _trackerDot('Submitted', true),
                          _trackerLine(job.applicationStatus != ApplicationStatus.submitted),
                          _trackerDot('Review', job.applicationStatus != ApplicationStatus.submitted),
                          _trackerLine(job.applicationStatus == ApplicationStatus.shortlisted || job.applicationStatus == ApplicationStatus.callSheetHold || job.applicationStatus == ApplicationStatus.booked),
                          _trackerDot('Shortlist', job.applicationStatus == ApplicationStatus.shortlisted || job.applicationStatus == ApplicationStatus.callSheetHold || job.applicationStatus == ApplicationStatus.booked),
                          _trackerLine(job.applicationStatus == ApplicationStatus.callSheetHold || job.applicationStatus == ApplicationStatus.booked),
                          _trackerDot('Hold', job.applicationStatus == ApplicationStatus.callSheetHold || job.applicationStatus == ApplicationStatus.booked),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _trackerDot(String title, bool isDone) {
    return Column(
      children: [
        CircleAvatar(
          radius: 8,
          backgroundColor: isDone ? CineColors.gold : CineColors.surfaceElevated,
          child: isDone
              ? const Icon(Icons.check, size: 10, color: Colors.black)
              : Container(width: 4, height: 4, decoration: const BoxDecoration(color: CineColors.textMuted, shape: BoxShape.circle)),
        ),
        const SizedBox(height: 2),
        Text(title, style: TextStyle(fontSize: 8.5, color: isDone ? CineColors.gold : CineColors.textMuted, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _trackerLine(bool isDone) {
    return Expanded(
      child: Container(
        height: 2,
        color: isDone ? CineColors.gold : CineColors.border,
        margin: const EdgeInsets.only(bottom: 12),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String title;
  final String subtitle;

  const _StatBlock({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CineColors.gold),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10.5, color: CineColors.textMuted),
        ),
      ],
    );
  }
}
