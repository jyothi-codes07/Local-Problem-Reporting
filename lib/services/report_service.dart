import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/report.dart';
import '../models/report_event.dart';
import 'auth_service.dart';
import 'notification_service.dart';

class ReportService extends ChangeNotifier {
  ReportService._();
  static final ReportService instance = ReportService._();
  factory ReportService() => instance;

  final SupabaseClient _supabase = Supabase.instance.client;

  void notifyReportsChanged() {
    notifyListeners();
  }

  Future<List<Report>> getReports() async {
    final response = await _supabase
        .from('reports')
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map((item) => Report.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<Report>> getMyReports() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      debugPrint('[ReportService] getMyReports: No authenticated user.');
      return [];
    }

    debugPrint('[ReportService] Fetching reports where reporter_id == ${user.id}');
    final response = await _supabase
        .from('reports')
        .select()
        .eq('reporter_id', user.id)
        .order('created_at', ascending: false);

    final list = (response as List)
        .map((item) => Report.fromMap(Map<String, dynamic>.from(item)))
        .toList();
    debugPrint('[ReportService] Retrieved ${list.length} reports for citizen ${user.id}');
    return list;
  }

  Future<List<Report>> getAssignedReports([String? workerId]) async {
    final effectiveId = workerId ?? _supabase.auth.currentUser?.id;
    if (effectiveId == null) {
      debugPrint('[ReportService] No authenticated worker user ID available.');
      return [];
    }

    debugPrint('[ReportService] Querying assigned reports where assigned_to == $effectiveId');
    final response = await _supabase
        .from('reports')
        .select()
        .eq('assigned_to', effectiveId)
        .order('created_at', ascending: false);

    final list = (response as List)
        .map((item) => Report.fromMap(Map<String, dynamic>.from(item)))
        .toList();
    debugPrint('[ReportService] Retrieved ${list.length} tasks for worker $effectiveId');
    return list;
  }

  Future<String?> uploadReportImage(Uint8List bytes) async {
    final fileName = 'report_${DateTime.now().millisecondsSinceEpoch}.jpg';
    // 1. Try dedicated 'report-images' bucket
    try {
      await _supabase.storage.from('report-images').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
      final publicUrl = _supabase.storage.from('report-images').getPublicUrl(fileName);
      return publicUrl;
    } catch (e1) {
      debugPrint('[ReportService] report-images bucket upload ($e1), trying reports bucket...');
      try {
        await _supabase.storage.from('reports').uploadBinary(
              fileName,
              bytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
            );
        final publicUrl = _supabase.storage.from('reports').getPublicUrl(fileName);
        return publicUrl;
      } catch (e2) {
        debugPrint('[ReportService] Storage bucket unavailable ($e2), persisting as base64 data URI in Supabase.');
        final base64 = base64Encode(bytes);
        return 'data:image/jpeg;base64,$base64';
      }
    }
  }

  Future<Report> createReport({
    required String title,
    required String description,
    required String category,
    required String severity,
    String? location,
    String? locationAddress,
    double? latitude,
    double? longitude,
    String? imageUrl,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Authentication required: user must be logged in to report a problem');
    }

    final profile = await AuthService.instance.getCurrentProfile();
    final reporterName = profile?.name ?? user.email?.split('@').first ?? 'Citizen';

    final effectiveAddress = locationAddress ?? location;
    final fullDescription = (effectiveAddress != null &&
            effectiveAddress.isNotEmpty &&
            !description.contains('Location:'))
        ? '$description\n\nLocation: $effectiveAddress'
        : description;

    final insertPayload = <String, dynamic>{
      'title': title,
      'description': fullDescription,
      'category': category,
      'severity': severity,
      'status': 'Reported',
      'reporter_id': user.id,
      'reporter_name': reporterName,
    };
    if (latitude != null) insertPayload['latitude'] = latitude;
    if (longitude != null) insertPayload['longitude'] = longitude;
    if (imageUrl != null && imageUrl.isNotEmpty) insertPayload['image_url'] = imageUrl;

    debugPrint('[ReportService] Inserting report with reporter_id: ${user.id}, reporter_name: $reporterName');
    final res = await _supabase.from('reports').insert(insertPayload).select().single();
    final created = Report.fromMap(Map<String, dynamic>.from(res));
    debugPrint('[ReportService] Created report with ID: ${created.id}, reporter_id: ${created.reporterId}');

    notifyListeners();

    // Create initial audit trail event
    await createReportEvent(
      reportId: created.id,
      actorId: user.id,
      actorName: reporterName,
      actorRole: 'citizen',
      action: 'reported',
      message: 'Complaint submitted by resident through LocalFix.',
    );

    // Notify authority of new complaint
    try {
      final authority = await AuthService.instance.getFirstAuthority();
      if (authority != null) {
        await NotificationService.instance.sendNotification(
          userId: authority.id,
          reportId: created.id,
          title: 'New civic complaint reported',
          message: '$reporterName reported a $category issue: $title',
          type: 'new_report',
        );
      }
    } catch (e) {
      debugPrint('Error sending authority notification on create: $e');
    }

    return created;
  }

  Future<Report?> getReportById(String id) async {
    final response = await _supabase
        .from('reports')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Report.fromMap(Map<String, dynamic>.from(response));
  }

  Future<void> updateReportStatus(
    String id,
    String status,
  ) async {
    await _supabase
        .from('reports')
        .update({'status': status})
        .eq('id', id);
    notifyListeners();
  }

  Future<void> assignReport(
    String id,
    String assignedTo, {
    String? workerName,
    String? authorityId,
    String? authorityName,
    Report? report,
  }) async {
    final authUser = _supabase.auth.currentUser;
    final authProfile = await AuthService.instance.getCurrentProfile();
    final effectiveAuthId = authorityId ?? authUser?.id;
    final effectiveAuthName = authorityName ?? authProfile?.name ?? 'Ward Authority';

    // If workerName is not provided, fetch from profiles
    String targetWorkerName = workerName ?? 'Assigned Worker';
    if (workerName == null) {
      try {
        final wProfile = await _supabase
            .from('profiles')
            .select('name')
            .eq('id', assignedTo)
            .maybeSingle();
        if (wProfile != null && wProfile['name'] != null) {
          targetWorkerName = wProfile['name'].toString();
        }
      } catch (_) {}
    }

    final updatePayload = <String, dynamic>{
      'assigned_to': assignedTo,
      'assigned_worker_name': targetWorkerName,
      'assigned_by': effectiveAuthId ?? effectiveAuthName,
      'status': 'Assigned',
    };

    await _supabase
        .from('reports')
        .update(updatePayload)
        .eq('id', id);

    // Audit trail event
    await createReportEvent(
      reportId: id,
      actorId: effectiveAuthId,
      actorName: effectiveAuthName,
      actorRole: 'authority',
      action: 'assigned',
      message: 'Task assigned to $targetWorkerName by $effectiveAuthName.',
    );

    // Notify assigned worker
    await NotificationService.instance.sendNotification(
      userId: assignedTo,
      reportId: id,
      title: 'New task assigned',
      message: 'You have been assigned a civic task by $effectiveAuthName.',
      type: 'assignment',
    );

    // Notify citizen if reporter_id is present
    final currentReport = report ?? await getReportById(id);
    if (currentReport?.reporterId != null) {
      await NotificationService.instance.sendNotification(
        userId: currentReport!.reporterId!,
        reportId: id,
        title: 'Task Assigned',
        message: 'Your complaint was assigned to $targetWorkerName.',
        type: 'status_update',
      );
    }
    notifyListeners();
  }

  Future<void> startWork({
    required Report report,
    required String workerId,
    required String workerName,
  }) async {
    await _supabase
        .from('reports')
        .update({'status': 'In Progress'})
        .eq('id', report.id);

    // 2. Create record in report_events
    await createReportEvent(
      reportId: report.id,
      actorId: workerId,
      actorName: workerName,
      actorRole: 'worker',
      action: 'work_started',
      message: '$workerName started work on ${report.title}',
    );

    // 3. Create notification for the authority who assigned the task
    String? authorityId = report.assignedBy;
    final isUuid = authorityId != null &&
        RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
            .hasMatch(authorityId);

    if (!isUuid) {
      final auth = await AuthService.instance.getFirstAuthority();
      authorityId = auth?.id;
    }

    if (authorityId != null) {
      await NotificationService.instance.sendNotification(
        userId: authorityId,
        reportId: report.id,
        title: 'Work Started',
        message: '$workerName has started work on ${report.title}.',
        type: 'work_started',
      );
    }

    // Also notify citizen
    if (report.reporterId != null) {
      await NotificationService.instance.sendNotification(
        userId: report.reporterId!,
        reportId: report.id,
        title: 'Work In Progress',
        message: 'Work has begun on your complaint "${report.title}".',
        type: 'status_update',
      );
    }
    notifyListeners();
  }

  Future<void> resolveReport({
    required Report report,
    required String workerId,
    required String workerName,
  }) async {
    await _supabase
        .from('reports')
        .update({'status': 'Resolved'})
        .eq('id', report.id);

    // Create audit event
    await createReportEvent(
      reportId: report.id,
      actorId: workerId,
      actorName: workerName,
      actorRole: 'worker',
      action: 'resolved',
      message: 'Problem resolved on site by $workerName.',
    );

    // Notify citizen
    if (report.reporterId != null) {
      await NotificationService.instance.sendNotification(
        userId: report.reporterId!,
        reportId: report.id,
        title: 'Complaint Resolved',
        message: 'Your complaint "${report.title}" has been resolved.',
        type: 'resolution',
      );
    }

    // Notify authority
    String? authorityId = report.assignedBy;
    final isUuid = authorityId != null &&
        RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
            .hasMatch(authorityId);

    if (!isUuid) {
      final auth = await AuthService.instance.getFirstAuthority();
      authorityId = auth?.id;
    }

    if (authorityId != null) {
      await NotificationService.instance.sendNotification(
        userId: authorityId,
        reportId: report.id,
        title: 'Complaint Resolved',
        message: '$workerName completed work and marked "${report.title}" as resolved.',
        type: 'resolution',
      );
    }
    notifyListeners();
  }

  Future<void> reviewReport({
    required Report report,
    required String authorityId,
    required String authorityName,
  }) async {
    await _supabase
        .from('reports')
        .update({'status': 'Under Review'})
        .eq('id', report.id);

    await createReportEvent(
      reportId: report.id,
      actorId: authorityId,
      actorName: authorityName,
      actorRole: 'authority',
      action: 'reviewed',
      message: 'Complaint reviewed by $authorityName.',
    );

    if (report.reporterId != null) {
      await NotificationService.instance.sendNotification(
        userId: report.reporterId!,
        reportId: report.id,
        title: 'Complaint Under Review',
        message: 'Your complaint "${report.title}" is now under review.',
        type: 'status_update',
      );
    }
    notifyListeners();
  }

  Future<List<ReportEvent>> getReportEvents(String reportId) async {
    try {
      final response = await _supabase
          .from('report_events')
          .select()
          .eq('report_id', reportId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((item) => ReportEvent.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('Error getting report events: $e');
      return [];
    }
  }

  Future<void> createReportEvent({
    required String reportId,
    String? actorId,
    required String actorName,
    required String actorRole,
    required String action,
    required String message,
  }) async {
    try {
      final payload = <String, dynamic>{
        'report_id': reportId,
        'actor_name': actorName,
        'actor_role': actorRole,
        'action': action,
        'message': message,
      };
      if (actorId != null) {
        payload['actor_id'] = actorId;
      }

      await _supabase.from('report_events').insert(payload);
    } catch (e) {
      debugPrint('Error creating report event: $e');
    }
  }
}