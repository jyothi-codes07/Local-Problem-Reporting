import 'package:flutter/material.dart';

import '../models/report.dart';
import 'status_badge.dart';

class ReportCard extends StatelessWidget {
  const ReportCard({
    super.key,
    required this.report,
    required this.onTap,
    this.compact = false,
  });

  final Report report;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      iconForCategory(report.category),
                      size: 16,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      report.category.label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  StatusBadge(status: report.status),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                report.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 6),
                Text(
                  report.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (report.assignedWorkerName != null &&
                  report.assignedWorkerName!.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.engineering_outlined,
                        size: 14,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Assigned to ${report.assignedWorkerName}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Row(
                children: [
                  Icon(Icons.place_outlined, size: 16, color: scheme.outline),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      report.locationAddress ?? report.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SeverityBadge(severity: report.severity),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData iconForCategory(ReportCategory category) {
  return switch (category) {
    ReportCategory.pothole => Icons.edit_road_rounded,
    ReportCategory.garbage => Icons.delete_outline_rounded,
    ReportCategory.streetlight => Icons.lightbulb_outline_rounded,
    ReportCategory.water => Icons.water_drop_outlined,
    ReportCategory.drainage => Icons.waves_rounded,
    ReportCategory.publicSpaces => Icons.park_outlined,
    ReportCategory.traffic => Icons.traffic_rounded,
    ReportCategory.other => Icons.flag_outlined,
  };
}
