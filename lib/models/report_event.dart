class ReportEvent {
  const ReportEvent({
    required this.id,
    required this.reportId,
    this.actorId,
    required this.actorName,
    required this.actorRole,
    required this.action,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String reportId;
  final String? actorId;
  final String actorName;
  final String actorRole;
  final String action;
  final String message;
  final DateTime createdAt;

  factory ReportEvent.fromMap(Map<String, dynamic> map) {
    return ReportEvent(
      id: map['id']?.toString() ?? '',
      reportId: map['report_id']?.toString() ?? '',
      actorId: map['actor_id']?.toString(),
      actorName: map['actor_name']?.toString() ?? 'Operations Desk',
      actorRole: map['actor_role']?.toString() ?? 'system',
      action: map['action']?.toString() ?? 'update',
      message: map['message']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'report_id': reportId,
      if (actorId != null) 'actor_id': actorId,
      'actor_name': actorName,
      'actor_role': actorRole,
      'action': action,
      'message': message,
    };
  }
}
