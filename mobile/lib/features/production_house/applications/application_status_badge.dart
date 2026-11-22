import 'package:flutter/material.dart';
import 'package:cineconnect/app/theme.dart';
import 'package:cineconnect/features/production_house/data/models/application.dart';

class ApplicationStatusBadge extends StatelessWidget {
  final ApplicationStatus status;

  const ApplicationStatusBadge({super.key, required this.status});

  Color get _color {
    switch (status) {
      case ApplicationStatus.received:
        return AppColors.textMuted;
      case ApplicationStatus.underReview:
        return AppColors.goldLight;
      case ApplicationStatus.shortlisted:
        return AppColors.gold;
      case ApplicationStatus.rejected:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 12, color: _color),
      ),
    );
  }
}