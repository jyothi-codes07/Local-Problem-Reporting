import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_theme.dart';
import '../models/report.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/report_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/report_card.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_badge.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'report_details_screen.dart';

class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({
    super.key,
    this.onNotificationTap,
    this.onProfileTap,
    this.onCompletedTabTap,
  });

  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onCompletedTabTap;

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  final ReportService _reportService = ReportService();
  final AuthService _authService = AuthService.instance;

  UserProfile? _profile;
  List<Report> _allAssignedReports = [];
  bool _isLoading = true;
  String? _error;
  bool _isActionRunning = false;
  String _selectedSection = 'active'; // 'active' or 'completed'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profile = await _authService.getCurrentProfile();
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) throw Exception('Worker not authenticated.');

      debugPrint('[WorkerDashboard] Authenticated worker ID: ${user.id} (${profile?.name})');
      final reports = await _reportService.getAssignedReports(user.id);
      debugPrint('[WorkerDashboard] Total reports matching assigned_to == ${user.id}: ${reports.length}');

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _allAssignedReports = reports;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load assigned tasks: $e';
        _isLoading = false;
      });
    }
  }

  int get _assignedCount => _allAssignedReports
      .where((r) =>
          r.status == ReportStatus.reported ||
          r.status == ReportStatus.underReview ||
          r.status == ReportStatus.assigned)
      .length;

  int get _inProgressCount => _allAssignedReports
      .where((r) => r.status == ReportStatus.inProgress)
      .length;

  int get _completedCount => _allAssignedReports
      .where((r) => r.status == ReportStatus.resolved)
      .length;

  int get _highPriorityCount => _allAssignedReports
      .where((r) => r.isHighPriority && r.isPending)
      .length;

  List<Report> get _activeTasks =>
      _allAssignedReports.where((r) => r.isPending).toList();

  List<Report> get _completedTasks =>
      _allAssignedReports.where((r) => r.status == ReportStatus.resolved).toList();

  void _openNotifications() {
    if (widget.onNotificationTap != null) {
      widget.onNotificationTap!();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const NotificationsScreen(showBackButton: true),
        ),
      );
    }
  }

  void _openProfile() {
    if (widget.onProfileTap != null) {
      widget.onProfileTap!();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const ProfileScreen(showBackButton: true),
        ),
      );
    }
  }

  Future<void> _startWork(Report report) async {
    if (_profile == null) return;

    setState(() {
      _isActionRunning = true;
      final idx = _allAssignedReports.indexWhere((r) => r.id == report.id);
      if (idx != -1) {
        _allAssignedReports[idx] = _allAssignedReports[idx].copyWith(
          status: ReportStatus.inProgress,
        );
      }
    });

    try {
      await _reportService.startWork(
        report: report,
        workerId: _profile!.id,
        workerName: _profile!.name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Work started'),
          backgroundColor: AppColors.info,
          duration: Duration(seconds: 2),
        ),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start work: $e'),
          backgroundColor: AppColors.critical,
        ),
      );
      await _loadData();
    } finally {
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  Future<void> _markResolved(Report report) async {
    if (_profile == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Task Resolution'),
        content: Text(
          'Confirm that field repairs for "${report.title}" are fully finished?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Confirm Resolved'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionRunning = true);
    try {
      await _reportService.resolveReport(
        report: report,
        workerId: _profile!.id,
        workerName: _profile!.name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task "${report.title}" marked as Resolved!'),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to resolve task: $e'),
          backgroundColor: AppColors.critical,
        ),
      );
    } finally {
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final activeTasks = _activeTasks;
    final completedTasks = _completedTasks;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // Header
                      SliverToBoxAdapter(
                        child: Container(
                          color: AppColors.surface,
                          padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.engineering_rounded,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'LocalFix · My Tasks',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.4,
                                        color: AppColors.dark,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Field Operator: ${_profile?.name ?? 'Worker'}',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: _openNotifications,
                                icon: const Icon(Icons.notifications_outlined),
                                tooltip: 'Notifications',
                              ),
                              IconButton(
                                onPressed: _openProfile,
                                icon: const Icon(Icons.account_circle_outlined),
                                tooltip: 'Profile',
                              ),
                              IconButton(
                                onPressed: () => _authService.signOut(context),
                                icon: const Icon(Icons.logout_rounded),
                                tooltip: 'Sign out',
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Metric Summary Cards
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Task Overview',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final wide = constraints.maxWidth > 560;
                                  final stats = [
                                    StatCard(
                                      label: 'Assigned',
                                      value: '$_assignedCount',
                                      icon: Icons.assignment_outlined,
                                      accent: AppColors.warning,
                                    ),
                                    StatCard(
                                      label: 'In Progress',
                                      value: '$_inProgressCount',
                                      icon: Icons.play_arrow_rounded,
                                      accent: AppColors.info,
                                    ),
                                    StatCard(
                                      label: 'Completed',
                                      value: '$_completedCount',
                                      icon: Icons.task_alt_rounded,
                                      accent: AppColors.success,
                                    ),
                                    StatCard(
                                      label: 'High Priority',
                                      value: '$_highPriorityCount',
                                      icon: Icons.priority_high_rounded,
                                      accent: AppColors.critical,
                                    ),
                                  ];

                                  return GridView.count(
                                    crossAxisCount: wide ? 4 : 2,
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                    childAspectRatio: wide ? 1.25 : 1.35,
                                    children: stats,
                                  );
                                },
                              ),
                              const SizedBox(height: 20),

                              // Segmented switcher for Active vs Completed
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _SegmentButton(
                                        label: 'MY ACTIVE TASKS (${activeTasks.length})',
                                        isSelected: _selectedSection == 'active',
                                        onTap: () => setState(() => _selectedSection = 'active'),
                                      ),
                                    ),
                                    Expanded(
                                      child: _SegmentButton(
                                        label: 'COMPLETED TASKS (${completedTasks.length})',
                                        isSelected: _selectedSection == 'completed',
                                        onTap: () => setState(() => _selectedSection = 'completed'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),

                      // Task List
                      if (_selectedSection == 'active') ...[
                        if (activeTasks.isEmpty)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                              child: EmptyStateView(
                                icon: Icons.assignment_turned_in_outlined,
                                title: 'No active tasks',
                                description:
                                    'You are all caught up! When the municipal authority assigns new complaints to you, they will appear here.',
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                            sliver: SliverList.separated(
                              itemCount: activeTasks.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                final report = activeTasks[index];
                                return _WorkerTaskCard(
                                  report: report,
                                  isActionRunning: _isActionRunning,
                                  onStartWork: () => _startWork(report),
                                  onMarkResolved: () => _markResolved(report),
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => ReportDetailsScreen(report: report),
                                      ),
                                    );
                                    _loadData();
                                  },
                                );
                              },
                            ),
                          ),
                      ] else ...[
                        if (completedTasks.isEmpty)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                              child: EmptyStateView(
                                icon: Icons.task_alt_rounded,
                                title: 'No completed tasks yet',
                                description:
                                    'Tasks you resolve on site will be archived here for record keeping.',
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                            sliver: SliverList.separated(
                              itemCount: completedTasks.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final report = completedTasks[index];
                                return ReportCard(
                                  report: report,
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => ReportDetailsScreen(report: report),
                                      ),
                                    );
                                    _loadData();
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    ],
                  ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      elevation: isSelected ? 1 : 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isSelected ? AppColors.dark : const Color(0xFF6B7E7B),
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkerTaskCard extends StatelessWidget {
  const _WorkerTaskCard({
    required this.report,
    required this.isActionRunning,
    required this.onStartWork,
    required this.onMarkResolved,
    required this.onTap,
  });

  final Report report;
  final bool isActionRunning;
  final VoidCallback onStartWork;
  final VoidCallback onMarkResolved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isInProgress = report.status == ReportStatus.inProgress;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isInProgress ? AppColors.info : AppColors.borderLight,
          width: isInProgress ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category, Severity, Status
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      iconForCategory(report.category),
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      report.category.label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  SeverityBadge(severity: report.severity),
                  const SizedBox(width: 8),
                  StatusBadge(status: report.status),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                report.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),

              // Description
              Text(
                report.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),

              // Location
              Row(
                children: [
                  const Icon(Icons.place_outlined, size: 16, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      report.locationAddress ?? report.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Authority name & Time
              Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 15, color: Color(0xFF6B7E7B)),
                  const SizedBox(width: 5),
                  Text(
                    'Assigned by: ${_formatAssignedBy(report.assignedBy)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF536360),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTime(report.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8B9E9A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('View Details'),
                  ),
                  const SizedBox(width: 8),
                  if (!isInProgress)
                    FilledButton.icon(
                      onPressed: isActionRunning ? null : onStartWork,
                      icon: isActionRunning
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text(isActionRunning ? 'STARTING...' : 'START WORK'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.info,
                        minimumSize: const Size(120, 42),
                      ),
                    )
                  else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.autorenew_rounded, size: 14, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text(
                            'IN PROGRESS',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: isActionRunning ? null : onMarkResolved,
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text('MARK RESOLVED'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        minimumSize: const Size(130, 42),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day} · $h:$m $ampm';
  }

  String _formatAssignedBy(String? assignedBy) {
    if (assignedBy == null || assignedBy.isEmpty) return 'Ward Authority';
    final isUuid = RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
        .hasMatch(assignedBy);
    return isUuid ? 'Ward Authority' : assignedBy;
  }
}
