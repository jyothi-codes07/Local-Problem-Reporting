import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/report.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Color dot) = switch (status) {
      ReportStatus.reported => (
        AppColors.warning.withValues(alpha: 0.15),
        const Color(0xFF9A5B00),
        AppColors.warning,
      ),
      ReportStatus.underReview => (
        AppColors.info.withValues(alpha: 0.15),
        const Color(0xFF1E40AF),
        AppColors.info,
      ),
      ReportStatus.assigned => (
        const Color(0xFFEDE9FE),
        const Color(0xFF6D28D9),
        const Color(0xFF7C3AED),
      ),
      ReportStatus.inProgress => (
        AppColors.primary.withValues(alpha: 0.15),
        AppColors.primary,
        AppColors.primary,
      ),
      ReportStatus.resolved => (
        AppColors.success.withValues(alpha: 0.15),
        AppColors.success,
        AppColors.success,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dot.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class SeverityBadge extends StatelessWidget {
  const SeverityBadge({super.key, required this.severity});

  final ReportSeverity severity;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Color border) = switch (severity) {
      ReportSeverity.low => (
        const Color(0xFFE8F0FE),
        const Color(0xFF1A56B0),
        const Color(0xFFBED2F7),
      ),
      ReportSeverity.medium => (
        AppColors.warning.withValues(alpha: 0.15),
        const Color(0xFF8A6100),
        AppColors.warning.withValues(alpha: 0.4),
      ),
      ReportSeverity.high => (
        const Color(0xFFFFECE5),
        const Color(0xFFC43A00),
        const Color(0xFFFFCCBA),
      ),
      ReportSeverity.critical => (
        AppColors.critical.withValues(alpha: 0.15),
        AppColors.critical,
        AppColors.critical.withValues(alpha: 0.4),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1),
      ),
      child: Text(
        severity.label.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
