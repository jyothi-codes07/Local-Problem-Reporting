import 'dart:convert';
import 'package:flutter/material.dart';

import '../models/report.dart';
import '../models/report_event.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/report_service.dart';
import '../widgets/location_map_widget.dart';
import '../widgets/report_card.dart';
import '../widgets/status_badge.dart';

class ReportDetailsScreen extends StatefulWidget {
  const ReportDetailsScreen({super.key, required this.report});

  final Report report;

  @override
  State<ReportDetailsScreen> createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen> {
  final ReportService _reportService = ReportService();
  final AuthService _authService = AuthService.instance;

  late Report _report;
  List<ReportEvent> _events = [];
  bool _isLoadingEvents = true;
  bool _isActionRunning = false;
  UserProfile? _currentProfile;

  @override
  void initState() {
    super.initState();
    _report = widget.report;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoadingEvents = true;
    });

    try {
      final profile = await _authService.getCurrentProfile();
      final refreshed = await _reportService.getReportById(_report.id);
      final events = await _reportService.getReportEvents(_report.id);

      if (!mounted) return;

      setState(() {
        if (refreshed != null) {
          _report = refreshed;
        }
        _currentProfile = profile;
        _events = events;
        _isLoadingEvents = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingEvents = false;
      });
    }
  }

  bool get _isAuthority => _currentProfile?.role == 'authority';
  bool get _isAssignedWorker =>
      _currentProfile?.role == 'worker' &&
      _report.assignedTo != null &&
      _report.assignedTo == _currentProfile?.id;

  Future<void> _startWork() async {
    if (_currentProfile == null) return;

    setState(() => _isActionRunning = true);
    try {
      await _reportService.startWork(
        report: _report,
        workerId: _currentProfile!.id,
        workerName: _currentProfile!.name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status updated: Work started!')),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start work: $e')),
      );
    } finally {
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  Future<void> _markResolved() async {
    if (_currentProfile == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Resolved'),
        content: const Text(
          'Confirm that the problem at this location has been completely resolved?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm Resolved'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionRunning = true);
    try {
      await _reportService.resolveReport(
        report: _report,
        workerId: _currentProfile!.id,
        workerName: _currentProfile!.name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complaint successfully marked as Resolved!')),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not mark resolved: $e')),
      );
    } finally {
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  Future<void> _openAssignWorkerSheet() async {
    final workers = await _authService.getWorkers();

    if (!mounted) return;

    if (workers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No registered workers found.')),
      );
      return;
    }

    final selectedWorker = await showModalBottomSheet<UserProfile>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.engineering_rounded),
                    const SizedBox(width: 8),
                    Text(
                      'Assign Field Worker',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Select a verified worker for "${_report.title}"',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                ...workers.map((w) {
                  final isCurrent = _report.assignedTo == w.id;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(ctx).colorScheme.primaryContainer,
                      child: Text(
                        w.name.isNotEmpty ? w.name[0].toUpperCase() : 'W',
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      w.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text('Role: ${w.role}'),
                    trailing: isCurrent
                        ? Chip(
                            label: const Text('Currently Assigned'),
                            backgroundColor:
                                Theme.of(ctx).colorScheme.secondaryContainer,
                          )
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(ctx).pop(w),
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (selectedWorker == null) return;

    setState(() => _isActionRunning = true);
    try {
      await _reportService.assignReport(
        _report.id,
        selectedWorker.id,
        workerName: selectedWorker.name,
        authorityId: _currentProfile?.id,
        authorityName: _currentProfile?.name ?? 'Ward Authority',
        report: _report,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task assigned to ${selectedWorker.name}!')),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to assign worker: $e')),
      );
    } finally {
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  Future<void> _reviewReport() async {
    if (_currentProfile == null) return;

    setState(() => _isActionRunning = true);
    try {
      await _reportService.reviewReport(
        report: _report,
        authorityId: _currentProfile!.id,
        authorityName: _currentProfile!.name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complaint marked as Under Review!')),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not review complaint: $e')),
      );
    } finally {
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Details'),
        actions: [
          IconButton(
            onPressed: _isLoadingEvents ? null : _loadData,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Row(
              children: [
                StatusBadge(status: _report.status),
                const SizedBox(width: 8),
                SeverityBadge(severity: _report.severity),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _report.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 20),
            _MetaCard(
              children: [
                _MetaRow(
                  icon: iconForCategory(_report.category),
                  label: 'Category',
                  value: _report.category.label,
                ),
                _MetaRow(
                  icon: Icons.place_outlined,
                  label: 'Location Address',
                  value: _report.locationAddress ?? _report.location,
                ),
                _MetaRow(
                  icon: Icons.person_outline,
                  label: 'Reported by',
                  value: _report.reporterName,
                ),
                if (_report.assignedWorkerName != null &&
                    _report.assignedWorkerName!.isNotEmpty)
                  _MetaRow(
                    icon: Icons.engineering_outlined,
                    label: 'Assigned Worker',
                    value: _report.assignedWorkerName!,
                    accent: scheme.primary,
                  ),
                _MetaRow(
                  icon: Icons.access_time_rounded,
                  label: 'Reported on',
                  value: _formatDateTime(_report.createdAt),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Description',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _report.description,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurface,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Photo Evidence Section
            if (_report.photoUrl != null && _report.photoUrl!.isNotEmpty) ...[
              _EvidencePhotoCard(photoUrl: _report.photoUrl!),
            ],

            // Incident Location Map Section
            if (_report.latitude != null && _report.longitude != null) ...[
              Text(
                'LOCATION & INCIDENT MAP',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              LocationMapPreview(
                latitude: _report.latitude!,
                longitude: _report.longitude!,
                address: _report.locationAddress ?? _report.location,
                height: 210,
              ),
              const SizedBox(height: 24),
            ],

            // Role actions section
            if (_isAuthority) ...[
              Text(
                'Authority Operations',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: _isActionRunning ? null : _openAssignWorkerSheet,
                    icon: const Icon(Icons.assignment_ind_rounded),
                    label: Text(_report.assignedTo == null
                        ? 'Assign Worker'
                        : 'Reassign Worker'),
                  ),
                  if (_report.status == ReportStatus.reported)
                    OutlinedButton.icon(
                      onPressed: _isActionRunning ? null : _reviewReport,
                      icon: const Icon(Icons.rate_review_outlined),
                      label: const Text('Mark Under Review'),
                    ),
                ],
              ),
              const SizedBox(height: 28),
            ],

            if (_isAssignedWorker) ...[
              Text(
                'Worker Actions',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (_report.status != ReportStatus.inProgress &&
                  _report.status != ReportStatus.resolved)
                FilledButton.icon(
                  onPressed: _isActionRunning ? null : _startWork,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start Work'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF175CD3),
                  ),
                ),
              if (_report.status == ReportStatus.inProgress)
                FilledButton.icon(
                  onPressed: _isActionRunning ? null : _markResolved,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Mark as Resolved'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF067647),
                  ),
                ),
              if (_report.status == ReportStatus.resolved)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7F0DC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_rounded, color: Color(0xFF146C2E)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You have completed and resolved this civic issue.',
                          style: TextStyle(
                            color: Color(0xFF146C2E),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 28),
            ],

            Text(
              'Timeline & Audit Trail',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),

            if (_isLoadingEvents)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_events.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: scheme.outline),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Reported · Submitted by resident.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(_events.length, (index) {
                final event = _events[index];
                final isLast = index == _events.length - 1;
                return _DatabaseTimelineTile(
                  event: event,
                  isLast: isLast,
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: children,
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
    this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = accent ?? scheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DatabaseTimelineTile extends StatelessWidget {
  const _DatabaseTimelineTile({
    required this.event,
    required this.isLast,
  });

  final ReportEvent event;
  final bool isLast;

  (Color, IconData) _indicator(String action, ColorScheme scheme) {
    switch (action.toLowerCase()) {
      case 'reported':
        return (scheme.primary, Icons.add_circle_outline_rounded);
      case 'reviewed':
        return (const Color(0xFFB54708), Icons.rate_review_rounded);
      case 'assigned':
        return (const Color(0xFF175CD3), Icons.assignment_ind_rounded);
      case 'work_started':
      case 'started':
        return (const Color(0xFFD97706), Icons.build_circle_rounded);
      case 'resolved':
        return (const Color(0xFF067647), Icons.check_circle_rounded);
      default:
        return (scheme.primary, Icons.circle_outlined);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (color, icon) = _indicator(event.action, scheme);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _titleForAction(event.action),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '· ${event.actorName}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateTime(event.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _titleForAction(String action) {
    switch (action.toLowerCase()) {
      case 'reported':
        return 'Reported';
      case 'reviewed':
        return 'Reviewed';
      case 'assigned':
        return 'Worker Assigned';
      case 'work_started':
      case 'started':
        return 'Work Started';
      case 'resolved':
        return 'Resolved';
      default:
        return action.isNotEmpty
            ? '${action[0].toUpperCase()}${action.substring(1)}'
            : 'Update';
    }
  }
}

String _formatDateTime(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final m = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $h:$m $ampm';
}

class _EvidencePhotoCard extends StatelessWidget {
  const _EvidencePhotoCard({required this.photoUrl});
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget imageWidget;
    if (photoUrl.startsWith('data:image')) {
      try {
        final commaIdx = photoUrl.indexOf(',');
        final base64Str = commaIdx != -1 ? photoUrl.substring(commaIdx + 1) : photoUrl;
        imageWidget = Image.memory(
          base64Decode(base64Str),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _errorPlaceholder(),
        );
      } catch (_) {
        imageWidget = _errorPlaceholder();
      }
    } else {
      imageWidget = Image.network(
        photoUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _errorPlaceholder(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EVIDENCE (ON-SITE PHOTO)',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            showDialog<void>(
              context: context,
              builder: (ctx) => Dialog(
                backgroundColor: Colors.black87,
                insetPadding: const EdgeInsets.all(12),
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: InteractiveViewer(
                        maxScale: 4.0,
                        child: imageWidget,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: scheme.surfaceContainerHighest,
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageWidget,
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Tap to view',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _errorPlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, size: 36, color: Colors.grey),
          SizedBox(height: 4),
          Text(
            'Unable to preview image',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
