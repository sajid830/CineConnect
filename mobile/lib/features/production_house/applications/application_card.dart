import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cineconnect/app/theme.dart';
import 'package:cineconnect/core/utils/formatters.dart';
import 'package:cineconnect/features/production_house/data/models/application.dart';
import 'package:cineconnect/shared/widgets/app_card.dart';
import 'package:cineconnect/shared/widgets/initials_avatar.dart';
import 'application_status_badge.dart';

class ApplicationCard extends StatelessWidget {
  final JobApplication application;
  final String opportunityTitle;

  const ApplicationCard({
    super.key,
    required this.application,
    required this.opportunityTitle,
  });

  @override
  Widget build(BuildContext context) {
    final a = application;
    final t = a.talent;

    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () => context.push('/applications/${a.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(initials: t.initials),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.fullName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      t.role,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ApplicationStatusBadge(status: a.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.campaign_outlined,
                size: 14,
                color: AppColors.gold,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  opportunityTitle,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.gold),
                ),
              ),
              Text(
                'Applied ${formatDate(a.appliedAt)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}