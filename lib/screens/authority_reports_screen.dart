import 'package:flutter/material.dart';

import '../models/report.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/report_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/report_card.dart';
import 'report_details_screen.dart';

class AuthorityReportsScreen extends StatefulWidget {
  const AuthorityReportsScreen({super.key});

  @override
  State<AuthorityReportsScreen> createState() => _AuthorityReportsScreenState();
}

class _AuthorityReportsScreenState extends State<AuthorityReportsScreen> {
  final ReportService _reportService = ReportService();
  final AuthService _authService = AuthService.instance;

  final TextEditingController _searchController = TextEditingController();
  List<Report> _reports = [];
  bool _isLoading = true;
  String? _error;

  String _statusFilter = 'all';
  String _severityFilter = 'all';
  ReportCategory? _categoryFilter;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final reports = await _reportService.getReports();
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load complaints: $e';
        _isLoading = false;
      });
    }
  }

  List<Report> get _filteredReports {
    final query = _searchController.text.trim().toLowerCase();

    return _reports.where((r) {
      // Status filter
      if (_statusFilter != 'all') {
        switch (_statusFilter) {
          case 'reported':
            if (r.status != ReportStatus.reported) return false;
            break;
          case 'underreview':
            if (r.status != ReportStatus.underReview) return false;
            break;
          case 'assigned':
            if (r.status != ReportStatus.assigned) return false;
            break;
          case 'inprogress':
            if (r.status != ReportStatus.inProgress) return false;
            break;
          case 'resolved':
            if (r.status != ReportStatus.resolved) return false;
            break;
        }
      }

      // Severity filter
      if (_severityFilter != 'all') {
        if (r.severity.name.toLowerCase() != _severityFilter) return false;
      }

      // Category filter
      if (_categoryFilter != null) {
        if (r.category != _categoryFilter) return false;
      }

      // Search query
      if (query.isNotEmpty) {
        final title = r.title.toLowerCase();
        final desc = r.description.toLowerCase();
        final loc = (r.locationAddress ?? r.location).toLowerCase();
        final cat = r.category.label.toLowerCase();
        final worker = r.assignedWorkerName?.toLowerCase() ?? '';
        final reporter = r.reporterName.toLowerCase();

        return title.contains(query) ||
            desc.contains(query) ||
            loc.contains(query) ||
            cat.contains(query) ||
            worker.contains(query) ||
            reporter.contains(query);
      }

      return true;
    }).toList();
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
                      backgroundColor:
                          Theme.of(ctx).colorScheme.primaryContainer,
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
      final profile = await _authService.getCurrentProfile();
      await _reportService.assignReport(
        report.id,
        selectedWorker.id,
        workerName: selectedWorker.name,
        authorityId: profile?.id,
        authorityName: profile?.name ?? 'Ward Authority',
        report: report,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Task successfully assigned to ${selectedWorker.name}!')),
      );
      _loadReports();
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
    final reports = _filteredReports;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'All Complaints',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Search and manage civic complaints across Ward 12.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),

              // Search box
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search complaints, worker, location...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 10),

              // Status filters
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All Status'),
                      selected: _statusFilter == 'all',
                      onSelected: (_) => setState(() => _statusFilter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Reported'),
                      selected: _statusFilter == 'reported',
                      onSelected: (_) =>
                          setState(() => _statusFilter = 'reported'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Under Review'),
                      selected: _statusFilter == 'underreview',
                      onSelected: (_) =>
                          setState(() => _statusFilter = 'underreview'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Assigned'),
                      selected: _statusFilter == 'assigned',
                      onSelected: (_) =>
                          setState(() => _statusFilter = 'assigned'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('In Progress'),
                      selected: _statusFilter == 'inprogress',
                      onSelected: (_) =>
                          setState(() => _statusFilter = 'inprogress'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Resolved'),
                      selected: _statusFilter == 'resolved',
                      onSelected: (_) =>
                          setState(() => _statusFilter = 'resolved'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Severity filters
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Text(
                      'Severity: ',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('Any'),
                      selected: _severityFilter == 'all',
                      onSelected: (_) =>
                          setState(() => _severityFilter = 'all'),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('Critical'),
                      selected: _severityFilter == 'critical',
                      onSelected: (_) =>
                          setState(() => _severityFilter = 'critical'),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('High'),
                      selected: _severityFilter == 'high',
                      onSelected: (_) =>
                          setState(() => _severityFilter = 'high'),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('Medium'),
                      selected: _severityFilter == 'medium',
                      onSelected: (_) =>
                          setState(() => _severityFilter = 'medium'),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('Low'),
                      selected: _severityFilter == 'low',
                      onSelected: (_) =>
                          setState(() => _severityFilter = 'low'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        Expanded(
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
                            onPressed: _loadReports,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : reports.isEmpty
                      ? RefreshIndicator(
                          onRefresh: _loadReports,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 60),
                              EmptyStateView(
                                icon: Icons.filter_alt_off_rounded,
                                title: 'No complaints found',
                                description:
                                    'No complaints match the selected filters or search terms.',
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadReports,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              20,
                              8,
                              20,
                              24,
                            ),
                            itemCount: reports.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final report = reports[index];

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ReportCard(
                                    report: report,
                                    onTap: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => ReportDetailsScreen(
                                            report: report,
                                          ),
                                        ),
                                      );
                                      _loadReports();
                                    },
                                  ),
                                  if (report.assignedTo == null) ...[
                                    const SizedBox(height: 4),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: FilledButton.tonalIcon(
                                        onPressed: () => _assignWorker(report),
                                        icon: const Icon(
                                            Icons.assignment_ind_rounded,
                                            size: 16),
                                        label: const Text('Dispatch Worker'),
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}
