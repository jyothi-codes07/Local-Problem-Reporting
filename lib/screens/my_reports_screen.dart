import 'package:flutter/material.dart';

import '../models/report.dart';
import '../services/report_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/report_card.dart';
import 'report_details_screen.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  final ReportService _reportService = ReportService();

  String _filter = 'all'; // 'all', 'active', 'inprogress', 'resolved'
  final TextEditingController _searchController = TextEditingController();
  List<Report> _reports = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reportService.addListener(_loadReports);
    _loadReports();
  }

  @override
  void dispose() {
    _reportService.removeListener(_loadReports);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    if (_reports.isEmpty) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final reports = await _reportService.getMyReports();

      if (!mounted) return;

      setState(() {
        _reports = reports;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not load your reports: $e';
        _isLoading = false;
      });
    }
  }

  List<Report> get _filteredReports {
    final query = _searchController.text.trim().toLowerCase();

    return _reports.where((r) {
      // Filter by status tab
      bool matchesStatus = true;
      switch (_filter) {
        case 'active':
          matchesStatus = r.status == ReportStatus.reported ||
              r.status == ReportStatus.underReview ||
              r.status == ReportStatus.assigned;
          break;
        case 'inprogress':
          matchesStatus = r.status == ReportStatus.inProgress;
          break;
        case 'resolved':
          matchesStatus = r.status == ReportStatus.resolved;
          break;
        case 'all':
        default:
          matchesStatus = true;
      }

      if (!matchesStatus) return false;

      // Filter by search query
      if (query.isNotEmpty) {
        final inTitle = r.title.toLowerCase().contains(query);
        final inDesc = r.description.toLowerCase().contains(query);
        final inCat = r.category.label.toLowerCase().contains(query);
        final inLoc = r.location.toLowerCase().contains(query);
        return inTitle || inDesc || inCat || inLoc;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final displayReports = _filteredReports;

    final allCount = _reports.length;
    final activeCount = _reports
        .where((r) =>
            r.status == ReportStatus.reported ||
            r.status == ReportStatus.underReview ||
            r.status == ReportStatus.assigned)
        .length;
    final inProgressCount =
        _reports.where((r) => r.status == ReportStatus.inProgress).length;
    final resolvedCount =
        _reports.where((r) => r.status == ReportStatus.resolved).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Reports',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$allCount civic complaint${allCount != 1 ? 's' : ''} on record',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),

              // Search bar
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search my complaints...',
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
              const SizedBox(height: 12),

              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: Text('All ($allCount)'),
                      selected: _filter == 'all',
                      onSelected: (_) => setState(() => _filter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text('Active ($activeCount)'),
                      selected: _filter == 'active',
                      onSelected: (_) => setState(() => _filter = 'active'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text('In Progress ($inProgressCount)'),
                      selected: _filter == 'inprogress',
                      onSelected: (_) => setState(() => _filter = 'inprogress'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text('Resolved ($resolvedCount)'),
                      selected: _filter == 'resolved',
                      onSelected: (_) => setState(() => _filter = 'resolved'),
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
                            onPressed: _loadReports,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : displayReports.isEmpty
                      ? RefreshIndicator(
                          onRefresh: _loadReports,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 60),
                              EmptyStateView(
                                icon: Icons.inbox_rounded,
                                title: _searchController.text.isNotEmpty
                                    ? 'No matching reports'
                                    : 'No reports in this tab',
                                description: _searchController.text.isNotEmpty
                                    ? 'Try checking for typos or searching a different term.'
                                    : 'When complaints reach this status, they will be listed here.',
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
                            itemCount: displayReports.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final report = displayReports[index];

                              return ReportCard(
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
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}