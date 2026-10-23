import 'package:flutter/foundation.dart';

import '../models/report.dart';

/// In-memory civic reports. Replace with a Supabase repository later.
class MockReportService extends ChangeNotifier {
  MockReportService._() : _reports = List<Report>.from(_seed);

  static final MockReportService instance = MockReportService._();

  final List<Report> _reports;

  List<Report> get reports {
    final copy = List<Report>.from(_reports);
    copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return copy;
  }

  Report? byId(String id) {
    for (final report in _reports) {
      if (report.id == id) return report;
    }
    return null;
  }

  int get totalCount => _reports.length;

  int get highPriorityCount =>
      _reports.where((r) => r.isHighPriority && r.isPending).length;

  int get pendingCount => _reports.where((r) => r.isPending).length;

  int get resolvedCount =>
      _reports.where((r) => r.status == ReportStatus.resolved).length;

  void addReport({
    required String title,
    required String description,
    required ReportCategory category,
    required String location,
    required ReportSeverity severity,
  }) {
    final now = DateTime.now();
    _reports.insert(
      0,
      Report(
        id: 'rpt-${now.millisecondsSinceEpoch}',
        title: title,
        description: description,
        category: category,
        location: location,
        severity: severity,
        status: ReportStatus.reported,
        createdAt: now,
        updatedAt: now,
        reporterName: 'You',
        timeline: [
          TimelineEvent(
            title: 'Reported',
            detail: 'Submitted by a resident through LocalFix.',
            occurredAt: now,
          ),
        ],
      ),
    );
    notifyListeners();
  }

  static final List<Report> _seed = [
    Report(
      id: 'rpt-1001',
      title: 'Deep pothole near bus stop 14',
      description:
          'A wide pothole has formed on the inbound lane. Two-wheelers are swerving into oncoming traffic during peak hours.',
      category: ReportCategory.pothole,
      location: 'MG Road & 5th Cross, Ward 12',
      latitude: 12.9716,
      longitude: 77.5946,
      severity: ReportSeverity.critical,
      status: ReportStatus.inProgress,
      createdAt: DateTime(2026, 10, 10, 8, 20),
      updatedAt: DateTime(2026, 10, 12, 16, 45),
      reporterName: 'A. Mehta',
      timeline: [
        TimelineEvent(
          title: 'Reported',
          detail: 'Citizen submitted photos and location.',
          occurredAt: DateTime(2026, 10, 10, 8, 20),
        ),
        TimelineEvent(
          title: 'Under Review',
          detail: 'Roads team verified the complaint.',
          occurredAt: DateTime(2026, 10, 10, 14, 05),
        ),
        TimelineEvent(
          title: 'In Progress',
          detail: 'Patch crew scheduled for this week.',
          occurredAt: DateTime(2026, 10, 12, 16, 45),
        ),
      ],
    ),
    Report(
      id: 'rpt-1002',
      title: 'Overflowing bins at market lane',
      description:
          'Municipal bins have not been collected for four days. Waste is spilling onto the pedestrian path.',
      category: ReportCategory.garbage,
      location: 'City Market Lane, Block B',
      severity: ReportSeverity.high,
      status: ReportStatus.underReview,
      createdAt: DateTime(2026, 10, 11, 18, 10),
      updatedAt: DateTime(2026, 10, 12, 9, 30),
      reporterName: 'S. Iyer',
      timeline: [
        TimelineEvent(
          title: 'Reported',
          detail: 'Logged via LocalFix.',
          occurredAt: DateTime(2026, 10, 11, 18, 10),
        ),
        TimelineEvent(
          title: 'Under Review',
          detail: 'Sanitation desk assigned a ward inspector.',
          occurredAt: DateTime(2026, 10, 12, 9, 30),
        ),
      ],
    ),
    Report(
      id: 'rpt-1003',
      title: 'Streetlight out on Park Avenue',
      description:
          'The pole near the children\'s park has been dark for a week, making the walking path unsafe after 7 pm.',
      category: ReportCategory.streetlight,
      location: 'Park Avenue, opposite Gate 2',
      severity: ReportSeverity.medium,
      status: ReportStatus.reported,
      createdAt: DateTime(2026, 10, 12, 21, 02),
      updatedAt: DateTime(2026, 10, 12, 21, 02),
      reporterName: 'N. Rao',
      timeline: [
        TimelineEvent(
          title: 'Reported',
          detail: 'Awaiting electrical maintenance review.',
          occurredAt: DateTime(2026, 10, 12, 21, 02),
        ),
      ],
    ),
    Report(
      id: 'rpt-1004',
      title: 'Low water pressure in Tower C',
      description:
          'Residents on floors 4–8 have had almost no municipal water since Sunday morning.',
      category: ReportCategory.water,
      location: 'Greenview Apts, Tower C, Ward 8',
      severity: ReportSeverity.high,
      status: ReportStatus.inProgress,
      createdAt: DateTime(2026, 10, 9, 7, 40),
      updatedAt: DateTime(2026, 10, 11, 11, 15),
      reporterName: 'R. Kapoor',
      timeline: [
        TimelineEvent(
          title: 'Reported',
          detail: 'Multiple households confirmed the outage.',
          occurredAt: DateTime(2026, 10, 9, 7, 40),
        ),
        TimelineEvent(
          title: 'In Progress',
          detail: 'Valve inspection underway at the feeder line.',
          occurredAt: DateTime(2026, 10, 11, 11, 15),
        ),
      ],
    ),
    Report(
      id: 'rpt-1005',
      title: 'Clogged storm drain after rains',
      description:
          'Standing water remains on the corner for more than 24 hours after rainfall, with a strong sewage odor.',
      category: ReportCategory.drainage,
      location: 'Lakeview Circle, Ward 4',
      severity: ReportSeverity.medium,
      status: ReportStatus.resolved,
      createdAt: DateTime(2026, 10, 4, 10, 00),
      updatedAt: DateTime(2026, 10, 8, 17, 20),
      reporterName: 'P. Das',
      timeline: [
        TimelineEvent(
          title: 'Reported',
          detail: 'Logged after monsoon showers.',
          occurredAt: DateTime(2026, 10, 4, 10, 00),
        ),
        TimelineEvent(
          title: 'In Progress',
          detail: 'Drain desilting team dispatched.',
          occurredAt: DateTime(2026, 10, 6, 13, 40),
        ),
        TimelineEvent(
          title: 'Resolved',
          detail: 'Drain cleared and water receded. Case closed.',
          occurredAt: DateTime(2026, 10, 8, 17, 20),
        ),
      ],
    ),
    Report(
      id: 'rpt-1006',
      title: 'Broken footpath tiles near school',
      description:
          'Several tiles are loose near the school gate, creating a trip hazard for students in the morning rush.',
      category: ReportCategory.other,
      location: 'St. Mary\'s School, East Gate',
      severity: ReportSeverity.low,
      status: ReportStatus.resolved,
      createdAt: DateTime(2026, 9, 28, 9, 15),
      updatedAt: DateTime(2026, 10, 2, 15, 00),
      reporterName: 'K. Nair',
      timeline: [
        TimelineEvent(
          title: 'Reported',
          detail: 'PTA member submitted the complaint.',
          occurredAt: DateTime(2026, 9, 28, 9, 15),
        ),
        TimelineEvent(
          title: 'Resolved',
          detail: 'Tiles replaced by the ward works team.',
          occurredAt: DateTime(2026, 10, 2, 15, 00),
        ),
      ],
    ),
  ];
}
