enum ReportCategory {
  pothole,
  garbage,
  streetlight,
  water,
  drainage,
  publicSpaces,
  traffic,
  other;

  String get label => switch (this) {
    ReportCategory.pothole => 'Potholes / Roads',
    ReportCategory.garbage => 'Garbage',
    ReportCategory.streetlight => 'Streetlights',
    ReportCategory.water => 'Water Supply',
    ReportCategory.drainage => 'Drainage',
    ReportCategory.publicSpaces => 'Public Spaces',
    ReportCategory.traffic => 'Traffic / Signals',
    ReportCategory.other => 'Other',
  };

  String get shortLabel => switch (this) {
    ReportCategory.pothole => 'Roads',
    ReportCategory.garbage => 'Garbage',
    ReportCategory.streetlight => 'Streetlights',
    ReportCategory.water => 'Water',
    ReportCategory.drainage => 'Drainage',
    ReportCategory.publicSpaces => 'Public Spaces',
    ReportCategory.traffic => 'Traffic',
    ReportCategory.other => 'Other',
  };
}

enum ReportSeverity {
  low,
  medium,
  high,
  critical;

  String get label => switch (this) {
    ReportSeverity.low => 'Low',
    ReportSeverity.medium => 'Medium',
    ReportSeverity.high => 'High',
    ReportSeverity.critical => 'Critical',
  };
}

enum ReportStatus {
  reported,
  underReview,
  assigned,
  inProgress,
  resolved;

  String get label => switch (this) {
    ReportStatus.reported => 'Reported',
    ReportStatus.underReview => 'Under Review',
    ReportStatus.assigned => 'Assigned',
    ReportStatus.inProgress => 'In Progress',
    ReportStatus.resolved => 'Resolved',
  };
}

class TimelineEvent {
  const TimelineEvent({
    required this.title,
    required this.detail,
    required this.occurredAt,
  });

  final String title;
  final String detail;
  final DateTime occurredAt;
}

class Report {
  const Report({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    required this.severity,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.photoUrl,
    this.latitude,
    this.longitude,
    this.locationAddress,
    this.reporterId,
    this.reporterName = 'Citizen',
    this.assignedTo,
    this.assignedBy,
    this.assignedWorkerName,
    this.timeline = const [],
  });

  final String id;
  final String title;
  final String description;
  final ReportCategory category;
  final String location;
  final double? latitude;
  final double? longitude;
  final String? photoUrl;
  final String? locationAddress;
  final ReportSeverity severity;
  final ReportStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? reporterId;
  final String reporterName;
  final String? assignedTo;
  final String? assignedBy;
  final String? assignedWorkerName;
  final List<TimelineEvent> timeline;

  bool get isHighPriority =>
      severity == ReportSeverity.high ||
      severity == ReportSeverity.critical;

  bool get isPending => status != ReportStatus.resolved;

  Report copyWith({
    String? id,
    String? title,
    String? description,
    ReportCategory? category,
    String? location,
    double? latitude,
    double? longitude,
    String? photoUrl,
    String? locationAddress,
    ReportSeverity? severity,
    ReportStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? reporterId,
    String? reporterName,
    String? assignedTo,
    String? assignedBy,
    String? assignedWorkerName,
    List<TimelineEvent>? timeline,
  }) {
    return Report(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      photoUrl: photoUrl ?? this.photoUrl,
      locationAddress: locationAddress ?? this.locationAddress,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reporterId: reporterId ?? this.reporterId,
      reporterName: reporterName ?? this.reporterName,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedBy: assignedBy ?? this.assignedBy,
      assignedWorkerName: assignedWorkerName ?? this.assignedWorkerName,
      timeline: timeline ?? this.timeline,
    );
  }

  factory Report.fromMap(Map<String, dynamic> map) {
    final createdAt =
        DateTime.tryParse(map['created_at']?.toString() ?? '') ??
        DateTime.now();

    final rawAddress = map['location_address']?.toString();
    String? resolvedAddress = (rawAddress != null && rawAddress.isNotEmpty) ? rawAddress : null;
    if (resolvedAddress == null) {
      final desc = map['description']?.toString() ?? '';
      final match = RegExp(r'(?:Location|Landmark/Area):\s*(.+)', caseSensitive: false).firstMatch(desc);
      if (match != null) {
        resolvedAddress = match.group(1)?.trim();
      }
    }

    final loc = map['location']?.toString();
    final location = (resolvedAddress != null && resolvedAddress.isNotEmpty)
        ? resolvedAddress
        : (loc != null && loc.isNotEmpty)
            ? loc
            : (map['latitude'] != null && map['longitude'] != null)
                ? 'Lat: ${map['latitude']}, Long: ${map['longitude']}'
                : 'Ward 12 · Central';

    return Report(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      category: _categoryFromString(map['category']),
      location: location,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      photoUrl: map['image_url']?.toString(),
      locationAddress: resolvedAddress ?? location,
      severity: _severityFromString(map['severity']),
      status: _statusFromString(map['status']),
      createdAt: createdAt,
      updatedAt: createdAt,
      reporterId: map['reporter_id']?.toString(),
      reporterName: map['reporter_name']?.toString() ?? 'Citizen',
      assignedTo: map['assigned_to']?.toString(),
      assignedBy: map['assigned_by']?.toString(),
      assignedWorkerName: map['assigned_worker_name']?.toString(),
    );
  }

  static ReportCategory _categoryFromString(dynamic value) {
    final text = value?.toString().toLowerCase().trim() ?? '';

    switch (text) {
      case 'pothole':
      case 'potholes':
      case 'roads':
      case 'road':
      case 'road & pothole':
      case 'potholes / roads':
        return ReportCategory.pothole;
      case 'garbage':
      case 'waste':
        return ReportCategory.garbage;
      case 'streetlight':
      case 'streetlights':
      case 'lights':
      case 'lighting':
        return ReportCategory.streetlight;
      case 'water':
      case 'water supply':
        return ReportCategory.water;
      case 'drainage':
      case 'sewage':
        return ReportCategory.drainage;
      case 'public spaces':
      case 'public space':
      case 'park':
      case 'parks':
        return ReportCategory.publicSpaces;
      case 'traffic':
      case 'traffic / signals':
      case 'traffic signals':
      case 'signals':
        return ReportCategory.traffic;
      default:
        return ReportCategory.other;
    }
  }

  static ReportSeverity _severityFromString(dynamic value) {
    switch (value?.toString().toLowerCase().trim()) {
      case 'low':
        return ReportSeverity.low;
      case 'high':
        return ReportSeverity.high;
      case 'critical':
        return ReportSeverity.critical;
      default:
        return ReportSeverity.medium;
    }
  }

  static ReportStatus _statusFromString(dynamic value) {
    switch (value?.toString().toLowerCase().trim()) {
      case 'under review':
      case 'underreview':
        return ReportStatus.underReview;
      case 'assigned':
        return ReportStatus.assigned;
      case 'in progress':
      case 'inprogress':
        return ReportStatus.inProgress;
      case 'resolved':
      case 'completed':
        return ReportStatus.resolved;
      default:
        return ReportStatus.reported;
    }
  }
}