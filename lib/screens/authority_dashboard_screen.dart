import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/report.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/report_service.dart';
import '../widgets/app_header.dart';
import '../widgets/empty_state.dart';
import '../widgets/report_card.dart';
import '../widgets/section_header.dart';
import '../widgets/stat_card.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'report_details_screen.dart';

class AuthorityDashboardScreen extends StatefulWidget {
  const AuthorityDashboardScreen({
    super.key,
    this.onNotificationTap,
    this.onProfileTap,
    this.onViewAllReports,
  });

  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onViewAllReports;

  @override
  State<AuthorityDashboardScreen> createState() =>
      _AuthorityDashboardScreenState();
}

class _AuthorityDashboardScreenState
    extends State<AuthorityDashboardScreen> {
  final ReportService _reportService = ReportService();
  final AuthService _authService = AuthService.instance;

  UserProfile? _profile;
  List<Report> _reports = [];
  bool _isLoading = true;
  String? _error;

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
      final reports = await _reportService.getReports();

      if (!mounted) return;

      setState(() {
        _profile = profile;
        _reports = reports;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not load reports from operations desk.';
        _isLoading = false;
      });
    }
  }

  int get _highPriorityCount =>
      _reports.where((report) => report.isHighPriority && report.isPending).length;

  int get _pendingCount =>
      _reports.where((report) => report.status == ReportStatus.reported || report.status == ReportStatus.underReview || report.status == ReportStatus.assigned).length;

  int get _inProgressCount =>
      _reports.where((report) => report.status == ReportStatus.inProgress).length;

  int get _resolvedCount =>
      _reports.where((report) => report.status == ReportStatus.resolved).length;

  List<Report> get _priorityQueue =>
      _reports.where((r) => r.isHighPriority && r.isPending).toList();

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

  Future<void> _assignWorker(Report report) async {
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
                      'Dispatch Field Worker',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Assign a certified worker for "${report.title}"',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                ...workers.map((w) {
                  final isCurrent = report.assignedTo == w.id;
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

    try {
      await _reportService.assignReport(
        report.id,
        selectedWorker.id,
        workerName: selectedWorker.name,
        authorityId: _profile?.id,
        authorityName: _profile?.name ?? 'Ward Authority',
        report: report,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task successfully assigned to ${selectedWorker.name}!')),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to assign worker: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final priorityReports = _priorityQueue;
    final recentReports = _reports.take(5).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
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
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppHeader(
                            title: 'Operations Center',
                            subtitle: '${_profile?.name ?? 'Ward Authority'} · Central Command',
                            profile: _profile,
                            onNotificationTap: _openNotifications,
                            onProfileTap: _openProfile,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Overview',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final wide = constraints.maxWidth > 560;

                                    final stats = [
                                      StatCard(
                                        label: 'Total complaints',
                                        value: '${_reports.length}',
                                        icon: Icons.assignment_outlined,
                                        accent: AppColors.primary,
                                      ),
                                      StatCard(
                                        label: 'Critical / high',
                                        value: '$_highPriorityCount',
                                        icon: Icons.priority_high_rounded,
                                        accent: AppColors.critical,
                                      ),
                                      StatCard(
                                        label: 'Pending',
                                        value: '$_pendingCount',
                                        icon: Icons.hourglass_top_rounded,
                                        accent: AppColors.warning,
                                      ),
                                      StatCard(
                                        label: 'In Progress',
                                        value: '$_inProgressCount',
                                        icon: Icons.pending_actions_rounded,
                                        accent: AppColors.info,
                                      ),
                                      StatCard(
                                        label: 'Resolved',
                                        value: '$_resolvedCount',
                                        icon: Icons.verified_outlined,
                                        accent: AppColors.success,
                                      ),
                                    ];

                                    return GridView.count(
                                      crossAxisCount: wide ? 5 : 2,
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      mainAxisSpacing: 10,
                                      crossAxisSpacing: 10,
                                      childAspectRatio: wide ? 1.2 : 1.3,
                                      children: stats,
                                    );
                                  },
                                ),
                                const SizedBox(height: 24),

                                // PRIORITY QUEUE SECTION
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      color: AppColors.critical,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Priority Queue (${priorityReports.length})',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.critical,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Urgent & critical civic issues requiring immediate dispatch.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Priority reports list
                    if (priorityReports.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD7F0DC).withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF067647).withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle_outline, color: Color(0xFF067647)),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'No critical or high-priority complaints pending in the queue.',
                                    style: TextStyle(
                                      color: Color(0xFF146C2E),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        sliver: SliverList.separated(
                          itemCount: priorityReports.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final report = priorityReports[index];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ReportCard(
                                  report: report,
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => ReportDetailsScreen(report: report),
                                      ),
                                    );
                                    _loadData();
                                  },
                                ),
                                if (report.assignedTo == null) ...[
                                  const SizedBox(height: 4),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: FilledButton.tonalIcon(
                                      onPressed: () => _assignWorker(report),
                                      icon: const Icon(Icons.assignment_ind_rounded, size: 16),
                                      label: const Text('Dispatch Worker'),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),

                    // Recent Complaints header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: SectionHeader(
                          title: 'Recent Complaints',
                          actionLabel: widget.onViewAllReports != null ? 'View all' : null,
                          onAction: widget.onViewAllReports,
                        ),
                      ),
                    ),

                    if (recentReports.isEmpty)
                      const SliverToBoxAdapter(
                        child: EmptyStateView(
                          icon: Icons.check_circle_outline_rounded,
                          title: 'No complaints logged',
                          description: 'No civic reports currently in the system.',
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                        sliver: SliverList.separated(
                          itemCount: recentReports.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final report = recentReports[index];
                            return ReportCard(
                              report: report,
                              compact: true,
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
                ),
    );
  }
}