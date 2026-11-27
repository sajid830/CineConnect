import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cineconnect/app/theme.dart';
import '../../core/models/craft_models.dart';
import '../../core/services/media_upload_service.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/formatters.dart';
import '../../features/production_house/data/models/project.dart';

class NaukriCastingBoard extends StatefulWidget {
  final CineAppState appState;

  const NaukriCastingBoard({super.key, required this.appState});

  @override
  State<NaukriCastingBoard> createState() => _NaukriCastingBoardState();
}

class _NaukriCastingBoardState extends State<NaukriCastingBoard> {
  int _activeSubTab = 0; // 0: Jobs, 1: Projects, 2: Application Status
  String _selectedCraftFilter = 'All Crafts';
  Timer? _liveRefreshTimer;

  @override
  void initState() {
    super.initState();
    widget.appState.loadOpportunities(forceRefresh: true);
    widget.appState.loadPublicProjects(forceRefresh: true);

    // Asynchronously poll every 5 seconds to get newly released applications/opportunities immediately
    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      widget.appState.loadOpportunities(forceRefresh: true);
      widget.appState.loadPublicProjects(forceRefresh: true);
    });
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    super.dispose();
  }

  void _showProjectApplicationDialog(Project project) {
    final noteController = TextEditingController();
    XFile? selectedVideoFile;
    String? selectedVideoFileName;
    PlatformFile? selectedResumeFile;
    String? selectedResumeFileName;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF13141C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: CineColors.gold, width: 1.2),
          ),
          title: Row(
            children: [
              const Icon(Icons.movie_filter_rounded, color: CineColors.gold, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Apply: ${project.title}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Production: ${project.productionHouseName ?? "Production House"} • ${project.projectType ?? "Production"}',
                  style: const TextStyle(fontSize: 11.5, color: CineColors.goldLight),
                ),
                if (project.budget != null && project.budget!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Budget: ${project.budget}',
                    style: const TextStyle(fontSize: 11.5, color: CineColors.gold, fontWeight: FontWeight.bold),
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Cover Note / Pitch:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: CineColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 12, color: CineColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Introduce yourself and describe why you are a great fit for this production...',
                    hintStyle: const TextStyle(fontSize: 11.5, color: CineColors.textMuted),
                    filled: true,
                    fillColor: Colors.black,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: CineColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: CineColors.gold),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: isSubmitting
                      ? null
                      : () async {
                          try {
                            final picker = ImagePicker();
                            final picked = await picker.pickVideo(source: ImageSource.gallery);
                            if (picked != null) {
                              setDialogState(() {
                                selectedVideoFile = picked;
                                selectedVideoFileName = picked.name;
                              });
                            }
                          } catch (_) {}
                        },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: CineColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selectedVideoFile != null ? CineColors.gold : CineColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selectedVideoFile != null ? Icons.check_circle : Icons.video_call_outlined,
                          color: CineColors.gold,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            selectedVideoFileName ?? 'Attach Showreel / Audition Tape (Optional)',
                            style: const TextStyle(fontSize: 11, color: CineColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: isSubmitting
                      ? null
                      : () async {
                          try {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['pdf', 'doc', 'docx'],
                            );
                            if (result != null && result.files.isNotEmpty) {
                              setDialogState(() {
                                selectedResumeFile = result.files.first;
                                selectedResumeFileName = result.files.first.name;
                              });
                            }
                          } catch (_) {}
                        },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: CineColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selectedResumeFile != null ? CineColors.gold : CineColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selectedResumeFile != null ? Icons.check_circle : Icons.picture_as_pdf_outlined,
                          color: CineColors.gold,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            selectedResumeFileName ?? 'Attach Resume / Credits PDF (Optional)',
                            style: const TextStyle(fontSize: 11, color: CineColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: CineColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(ctx);
                      setDialogState(() => isSubmitting = true);
                      try {
                        String? uploadedReelUrl;
                        String? uploadedResumeUrl;
                        final uploader = MediaUploadService();
                        if (selectedVideoFile != null) {
                          final res = await uploader.uploadXFile(
                            file: selectedVideoFile!,
                            contentType: 'video/mp4',
                            purpose: 'private',
                          );
                          uploadedReelUrl = res.publicUrl;
                        }
                        if (selectedResumeFile != null) {
                          final res = await uploader.uploadPlatformFile(
                            file: selectedResumeFile!,
                            contentType: 'application/pdf',
                            purpose: 'private',
                          );
                          uploadedResumeUrl = res.publicUrl;
                        }

                        await widget.appState.applyToProject(
                          project.id,
                          coverLetter: noteController.text.trim(),
                          resumeUrl: uploadedResumeUrl,
                          selfTapeUrl: uploadedReelUrl,
                        );

                        if (mounted) {
                          navigator.pop();
                          messenger.showSnackBar(
                            const SnackBar(
                              backgroundColor: CineColors.gold,
                              content: Text('Application submitted successfully to project!'),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.red.shade900,
                              content: Text('Failed to submit application: $e'),
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: CineColors.gold,
                foregroundColor: Colors.black,
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Text('Submit Application', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getAvailableCraftFilters() {
    final crafts = <String>{'All Crafts'};
    for (final job in widget.appState.jobBriefs) {
      if (job.targetCraft.isNotEmpty) {
        crafts.add(job.targetCraft);
      }
    }
    crafts.addAll([
      'Cinematography / DOP',
      'Action & Stunt Director',
      'Sound Design & Atmos Mix',
    ]);
    return crafts.toList();
  }

  void _showSelfTapeSubmissionDialog(ProductionJobBrief job) {
    XFile? selectedVideoFile;
    String? selectedVideoFileName;
    int? selectedVideoSizeBytes;
    String? selectedVideoMimeType;
    String? cachedUploadedReelUrl;

    PlatformFile? selectedResumeFile;
    String? selectedResumeFileName;
    int? selectedResumeSizeBytes;
    String? cachedUploadedResumeUrl;

    bool isSubmitting = false;
    String? statusMessage;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Studio: ${job.studioName} • ${job.councilId}',
                  style: const TextStyle(fontSize: 11.5, color: CineColors.goldLight),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Formatted 12pt Courier Screenplay Sides:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: CineColors.textMuted,
                  ),
                ),
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

                // Interactive Video File Selection Card
                InkWell(
                  onTap: isSubmitting
                      ? null
                      : () async {
                          try {
                            final picker = ImagePicker();
                            final picked = await picker.pickVideo(
                              source: ImageSource.gallery,
                            );
                            if (picked != null) {
                              final length = await picked.length();
                              // Enforce the 100 MB backend limit early with clear feedback
                              if (length > 100 * 1024 * 1024) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      backgroundColor: CineColors.warning,
                                      content: Text(
                                        'Video file size exceeds maximum limit of 100 MB.',
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }
                              final name = picked.name;
                              final mime = MediaUploadService.resolveMimeType(name);
                              setDialogState(() {
                                selectedVideoFile = picked;
                                selectedVideoFileName = name;
                                selectedVideoSizeBytes = length;
                                selectedVideoMimeType =
                                    mime.startsWith('video/') ? mime : 'video/mp4';
                                cachedUploadedReelUrl = null;
                              });
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF3B1212),
                                  content: Text('Could not pick video: $e'),
                                ),
                              );
                            }
                          }
                        },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CineColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selectedVideoFile != null
                            ? CineColors.gold
                            : CineColors.border,
                        width: selectedVideoFile != null ? 1.2 : 1,
                      ),
                    ),
                    child: selectedVideoFile != null
                        ? Row(
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: CineColors.gold,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedVideoFileName ?? 'Self-Tape Video',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: CineColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${((selectedVideoSizeBytes ?? 0) / (1024 * 1024)).toStringAsFixed(1)} MB • Tap to replace',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        color: CineColors.goldLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isSubmitting)
                                IconButton(
                                  icon: const Icon(Icons.close,
                                      size: 18, color: CineColors.textMuted),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    setDialogState(() {
                                      selectedVideoFile = null;
                                      selectedVideoFileName = null;
                                      selectedVideoSizeBytes = null;
                                      selectedVideoMimeType = null;
                                      cachedUploadedReelUrl = null;
                                    });
                                  },
                                ),
                            ],
                          )
                        : const Row(
                            children: [
                              Icon(Icons.cloud_upload_outlined,
                                  color: CineColors.gold, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Attach Uncompressed Self-Tape (ProRes / MP4 1080p)',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: CineColors.textPrimary),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 10),

                // Interactive Resume / CV Selection Card (PDF Only)
                InkWell(
                  onTap: isSubmitting
                      ? null
                      : () async {
                          try {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['pdf'],
                              withReadStream: true,
                            );

                            if (result != null && result.files.isNotEmpty) {
                              final pickedFile = result.files.first;

                              // Validate PDF extension explicitly
                              final ext = (pickedFile.extension ?? '').toLowerCase();
                              final name = pickedFile.name.toLowerCase();
                              if (ext != 'pdf' && !name.endsWith('.pdf')) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      backgroundColor: CineColors.warning,
                                      content: Text(
                                        'Invalid document format. Only PDF resumes are accepted.',
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }

                              // Enforce the 100 MB backend limit early with clear feedback
                              final length = pickedFile.size;
                              if (length > 100 * 1024 * 1024) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      backgroundColor: CineColors.warning,
                                      content: Text(
                                        'Resume file size exceeds maximum limit of 100 MB.',
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }

                              setDialogState(() {
                                selectedResumeFile = pickedFile;
                                selectedResumeFileName = pickedFile.name;
                                selectedResumeSizeBytes = length;
                                cachedUploadedResumeUrl = null;
                              });
                            }
                            // Note: Cancelling preserves existing selection and cachedUploadedResumeUrl
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF3B1212),
                                  content: Text('Could not pick resume: $e'),
                                ),
                              );
                            }
                          }
                        },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CineColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selectedResumeFile != null
                            ? CineColors.gold
                            : CineColors.border,
                        width: selectedResumeFile != null ? 1.2 : 1,
                      ),
                    ),
                    child: selectedResumeFile != null
                        ? Row(
                            children: [
                              const Icon(
                                Icons.picture_as_pdf_rounded,
                                color: CineColors.gold,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedResumeFileName ?? 'Resume (PDF)',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: CineColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${((selectedResumeSizeBytes ?? 0) / (1024 * 1024) >= 0.1 ? '${((selectedResumeSizeBytes ?? 0) / (1024 * 1024)).toStringAsFixed(1)} MB' : '${((selectedResumeSizeBytes ?? 0) / 1024).toStringAsFixed(0)} KB')} • Tap to replace',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        color: CineColors.goldLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isSubmitting)
                                IconButton(
                                  icon: const Icon(Icons.close,
                                      size: 18, color: CineColors.textMuted),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    setDialogState(() {
                                      selectedResumeFile = null;
                                      selectedResumeFileName = null;
                                      selectedResumeSizeBytes = null;
                                      cachedUploadedResumeUrl = null;
                                    });
                                  },
                                ),
                            ],
                          )
                        : const Row(
                            children: [
                              Icon(Icons.description_outlined,
                                  color: CineColors.gold, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Attach Resume / CV (PDF format, max 100 MB)',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: CineColors.textPrimary),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                if (statusMessage != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: CineColors.gold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          statusMessage!,
                          style: const TextStyle(
                              fontSize: 11, color: CineColors.goldLight),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel',
                  style: TextStyle(color: CineColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() {
                        isSubmitting = true;
                      });

                      try {
                        String? uploadedReelUrl = cachedUploadedReelUrl;
                        String? uploadedResumeUrl = cachedUploadedResumeUrl;
                        final uploadService =
                            widget.appState.apiService.mediaUploadService;

                        // 1. If user selected a self-tape, stream upload to MinIO private bucket only if not already uploaded
                        if (selectedVideoFile != null &&
                            selectedVideoFileName != null &&
                            uploadedReelUrl == null) {
                          setDialogState(() {
                            statusMessage =
                                'Uploading self-tape to secure storage...';
                          });

                          final uploadRes = await uploadService.uploadXFile(
                            file: selectedVideoFile!,
                            contentType: selectedVideoMimeType ?? 'video/mp4',
                            purpose: 'private',
                          );
                          // Retain the stable canonical reference in dialog state for retries
                          uploadedReelUrl = uploadRes.publicUrl;
                          cachedUploadedReelUrl = uploadRes.publicUrl;
                        }

                        // 2. If user selected a resume, stream upload to MinIO private bucket only if not already uploaded
                        if (selectedResumeFile != null &&
                            selectedResumeFileName != null &&
                            uploadedResumeUrl == null) {
                          setDialogState(() {
                            statusMessage =
                                'Uploading resume to secure storage...';
                          });

                          final uploadRes = await uploadService.uploadPlatformFile(
                            file: selectedResumeFile!,
                            contentType: 'application/pdf',
                            purpose: 'private',
                          );
                          // Retain the stable canonical reference in dialog state for retries
                          uploadedResumeUrl = uploadRes.publicUrl;
                          cachedUploadedResumeUrl = uploadRes.publicUrl;
                        }

                        // 3. Submit application to backend with the reel url and resume url
                        setDialogState(() {
                          statusMessage = 'Submitting application to studio...';
                        });

                        await widget.appState.applyToJob(
                          job.id,
                          selfTapeUrl: uploadedReelUrl,
                          resumeUrl: uploadedResumeUrl,
                        );

                        if (context.mounted) {
                          cachedUploadedReelUrl = null;
                          cachedUploadedResumeUrl = null;
                          Navigator.of(ctx).pop();
                          final hasMedia = selectedVideoFile != null || selectedResumeFile != null;
                          final attachments = [
                            if (selectedVideoFile != null) 'Self-Tape',
                            if (selectedResumeFile != null) 'Resume',
                          ].join(' & ');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: CineColors.surfaceElevated,
                              content: Text(
                                hasMedia
                                    ? 'Application & $attachments Submitted to ${job.studioName}! Status: Under Director Review'
                                    : 'Application Submitted to ${job.studioName}! Status: Under Director Review',
                                style: const TextStyle(color: CineColors.gold),
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          isSubmitting = false;
                          statusMessage = null;
                        });
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF3B1212),
                              content: Text(
                                'Submission failed: $e',
                                style:
                                    const TextStyle(color: Color(0xFFFF8B8B)),
                              ),
                            ),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text('Submit 1-Tap Application'),
            ),
          ],
        ),
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
      case ApplicationStatus.rejected:
        return _statusPill('NOT SELECTED', Colors.redAccent);
      case ApplicationStatus.unknown:
        return _statusPill('STATUS PENDING', CineColors.textMuted);
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
    final appliedProjects = widget.appState.publicProjects.where((p) => p.hasUserApplied).toList();
    final totalApplicationsCount = appliedJobs.length + appliedProjects.length;
    final availableCrafts = _getAvailableCraftFilters();
    final effectiveCraftFilter = availableCrafts.contains(_selectedCraftFilter) ? _selectedCraftFilter : 'All Crafts';

    final filteredJobs = effectiveCraftFilter == 'All Crafts'
        ? widget.appState.jobBriefs
        : widget.appState.jobBriefs.where((j) => j.targetCraft == effectiveCraftFilter).toList();

    final suggestedJobs = [...filteredJobs]..sort(
        (a, b) => widget.appState
            .calculateSkillMatch(b.requiredSkills)
            .compareTo(widget.appState.calculateSkillMatch(a.requiredSkills)),
      );

    return RefreshIndicator(
      color: CineColors.gold,
      backgroundColor: CineColors.surfaceElevated,
      onRefresh: () async {
        await Future.wait([
          widget.appState.loadOpportunities(forceRefresh: true),
          widget.appState.loadPublicProjects(forceRefresh: true),
        ]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                        child: _StatBlock(title: '$totalApplicationsCount', subtitle: 'My Applications'),
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

            if (widget.appState.isUsingFallbackOpportunities)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: CineColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: CineColors.warning.withValues(alpha: 0.5), width: 0.8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 14, color: CineColors.warning),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Offline Mode • Displaying cached sample briefs',
                        style: TextStyle(fontSize: 10.5, color: CineColors.warning, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

          // Sub-Tab Segment (Jobs vs Projects vs Applications)
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
                            Icons.work_outline,
                            size: 14,
                            color: _activeSubTab == 0 ? CineColors.gold : CineColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Jobs',
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
                            Icons.movie_creation_outlined,
                            size: 14,
                            color: _activeSubTab == 1 ? CineColors.gold : CineColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Projects (${widget.appState.publicProjects.length})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
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
                const SizedBox(width: 4),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _activeSubTab = 2),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _activeSubTab == 2 ? CineColors.gold.withValues(alpha: 0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _activeSubTab == 2 ? CineColors.gold : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.assignment_turned_in_outlined,
                            size: 14,
                            color: _activeSubTab == 2 ? CineColors.gold : CineColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Status ($totalApplicationsCount)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: _activeSubTab == 2 ? FontWeight.bold : FontWeight.normal,
                                color: _activeSubTab == 2 ? CineColors.gold : CineColors.textMuted,
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
                    value: availableCrafts.contains(_selectedCraftFilter) ? _selectedCraftFilter : 'All Crafts',
                    dropdownColor: CineColors.surfaceElevated,
                    isExpanded: true,
                    items: availableCrafts
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
            if (widget.appState.isLoadingOpportunities && suggestedJobs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(color: CineColors.gold),
                ),
              )
            else if (suggestedJobs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.work_outline_rounded, size: 44, color: CineColors.textMuted),
                      const SizedBox(height: 10),
                      Text(
                        effectiveCraftFilter == 'All Crafts'
                            ? 'No open casting calls right now'
                            : 'No open calls for $effectiveCraftFilter',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: CineColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Pull down to refresh or check back later for new production briefs.',
                        textAlign: TextAlign.center,
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
                          if (job.experience != null && job.experience!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: CineColors.gold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: CineColors.gold.withValues(alpha: 0.4), width: 0.8),
                              ),
                              child: Text(
                                job.experience!,
                                style: const TextStyle(fontSize: 10, color: CineColors.gold, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
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
                              onPressed: job.hasUserApplied
                                  ? null
                                  : () => _showSelfTapeSubmissionDialog(job),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              child: Text(
                                job.hasUserApplied ? '✓ Applied' : 'Apply',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
          ] else if (_activeSubTab == 1) ...[
            // Public Projects Tab
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  const Icon(Icons.movie_creation_outlined, size: 16, color: CineColors.gold),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Published productions looking for talent and crew',
                      style: TextStyle(fontSize: 12, color: CineColors.textMuted),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18, color: CineColors.gold),
                    onPressed: () => widget.appState.loadPublicProjects(forceRefresh: true),
                  ),
                ],
              ),
            ),
            if (widget.appState.isLoadingProjects)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: CineColors.gold)),
              )
            else if (widget.appState.publicProjects.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.movie_outlined, size: 44, color: CineColors.textMuted),
                      const SizedBox(height: 10),
                      const Text(
                        'No production projects published yet',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: CineColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Production houses will post upcoming projects here.',
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
                itemCount: widget.appState.publicProjects.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final project = widget.appState.publicProjects[index];
                  final studioName = project.productionHouseName ?? 'Production Studio';
                  final studioLogo = project.productionHouseLogo ?? (studioName.length >= 2 ? studioName.substring(0, 2).toUpperCase() : 'PH');

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CineColors.surfaceCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: project.hasUserApplied
                            ? CineColors.success.withValues(alpha: 0.5)
                            : CineColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: CineColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: CineColors.gold.withValues(alpha: 0.4)),
                              ),
                              child: Center(
                                child: Text(
                                  studioLogo,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: CineColors.gold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    project.title,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: CineColors.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    studioName,
                                    style: const TextStyle(fontSize: 11.5, color: CineColors.goldLight),
                                  ),
                                ],
                              ),
                            ),
                            if (project.projectType != null && project.projectType!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: CineColors.gold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: CineColors.gold.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  project.projectType!,
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: CineColors.gold),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: CineColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: CineColors.border),
                              ),
                              child: Text(
                                project.status.label,
                                style: const TextStyle(fontSize: 11, color: CineColors.textMuted),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(Icons.calendar_today_outlined, size: 12, color: CineColors.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              'Starts: ${formatDate(project.startDate)}',
                              style: const TextStyle(fontSize: 11.5, color: CineColors.textMuted),
                            ),
                            if (project.budget != null && project.budget!.isNotEmpty) ...[
                              const Spacer(),
                              const Icon(Icons.currency_rupee, size: 12, color: CineColors.gold),
                              Text(
                                project.budget!,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CineColors.gold),
                              ),
                            ],
                          ],
                        ),
                        if (project.description.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            project.description,
                            style: const TextStyle(fontSize: 12.5, color: CineColors.textMuted, height: 1.4),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Text(
                              '${project.applicationsCount} Applicants',
                              style: const TextStyle(fontSize: 11, color: CineColors.textMuted),
                            ),
                            const Spacer(),
                            if (project.hasUserApplied)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F291E),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: CineColors.success),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_rounded, size: 14, color: CineColors.success),
                                    SizedBox(width: 6),
                                    Text(
                                      'Applied to Project',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CineColors.success),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ElevatedButton(
                                onPressed: () => _showProjectApplicationDialog(project),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: CineColors.gold,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text(
                                  'Apply to Project',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
            if (appliedJobs.isEmpty && appliedProjects.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        widget.appState.hasApplicationsLookupFailed
                            ? Icons.sync_problem_rounded
                            : Icons.assignment_outlined,
                        size: 44,
                        color: widget.appState.hasApplicationsLookupFailed
                            ? CineColors.warning
                            : CineColors.textMuted,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.appState.hasApplicationsLookupFailed
                            ? 'Application sync unavailable'
                            : 'No applications yet',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: CineColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.appState.hasApplicationsLookupFailed
                            ? 'Unable to sync application status from server. Pull down to retry.'
                            : 'Apply from Jobs or Projects to track status here.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11.5, color: CineColors.textMuted),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              if (appliedProjects.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.movie_creation_outlined, size: 14, color: CineColors.gold),
                      const SizedBox(width: 6),
                      Text(
                        'Project Applications (${appliedProjects.length})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CineColors.gold),
                      ),
                    ],
                  ),
                ),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: appliedProjects.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final project = appliedProjects[index];
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
                              Expanded(
                                child: Text(
                                  project.title,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              _buildStatusBadge(ProductionJobBrief.parseStatus(project.applicationStatus)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${project.productionHouseName ?? "Production House"} • Type: ${project.projectType ?? "Production"}',
                            style: const TextStyle(fontSize: 11.5, color: CineColors.goldLight),
                          ),
                          if (project.budget != null && project.budget!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('Budget: ${project.budget}', style: const TextStyle(fontSize: 11, color: CineColors.textMuted)),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _trackerDot('Submitted', true),
                              _trackerLine(project.applicationStatus != 'submitted' && project.applicationStatus != null),
                              _trackerDot('Review', project.applicationStatus != 'submitted' && project.applicationStatus != null),
                              _trackerLine(project.applicationStatus == 'shortlisted' || project.applicationStatus == 'accepted'),
                              _trackerDot('Shortlist', project.applicationStatus == 'shortlisted' || project.applicationStatus == 'accepted'),
                              _trackerLine(project.applicationStatus == 'accepted'),
                              _trackerDot('Booked', project.applicationStatus == 'accepted'),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
              if (appliedJobs.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.work_outline, size: 14, color: CineColors.gold),
                      const SizedBox(width: 6),
                      Text(
                        'Job Applications (${appliedJobs.length})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CineColors.gold),
                      ),
                    ],
                  ),
                ),
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
                              Expanded(
                                child: Text(job.projectTitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                              ),
                              _buildStatusBadge(job.applicationStatus),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('${job.studioName} • Role: ${job.targetCraft}',
                              style: const TextStyle(fontSize: 11.5, color: CineColors.goldLight)),
                          const SizedBox(height: 6),
                          Text('Shoot Window: ${job.shootWindow}', style: const TextStyle(fontSize: 11, color: CineColors.textMuted)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _trackerDot('Submitted', true),
                              _trackerLine(job.applicationStatus != ApplicationStatus.submitted &&
                                  job.applicationStatus != ApplicationStatus.rejected &&
                                  job.applicationStatus != ApplicationStatus.unknown),
                              _trackerDot(
                                  'Review',
                                  job.applicationStatus != ApplicationStatus.submitted &&
                                      job.applicationStatus != ApplicationStatus.rejected &&
                                      job.applicationStatus != ApplicationStatus.unknown),
                              _trackerLine(job.applicationStatus == ApplicationStatus.shortlisted ||
                                  job.applicationStatus == ApplicationStatus.callSheetHold ||
                                  job.applicationStatus == ApplicationStatus.booked),
                              _trackerDot(
                                  'Shortlist',
                                  job.applicationStatus == ApplicationStatus.shortlisted ||
                                      job.applicationStatus == ApplicationStatus.callSheetHold ||
                                      job.applicationStatus == ApplicationStatus.booked),
                              _trackerLine(job.applicationStatus == ApplicationStatus.callSheetHold ||
                                  job.applicationStatus == ApplicationStatus.booked),
                              _trackerDot(
                                  'Hold',
                                  job.applicationStatus == ApplicationStatus.callSheetHold ||
                                      job.applicationStatus == ApplicationStatus.booked),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ],
        ],
      ),
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
