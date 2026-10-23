import 'package:flutter/material.dart';

import '../models/report.dart';
import '../services/auth_service.dart';
import '../services/report_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/report_card.dart';
import 'report_details_screen.dart';

class WorkerCompletedScreen extends StatefulWidget {
  const WorkerCompletedScreen({super.key});

  @override
  State<WorkerCompletedScreen> createState() => _WorkerCompletedScreenState();
}

class _WorkerCompletedScreenState extends State<WorkerCompletedScreen> {
  final ReportService _reportService = ReportService();
  final AuthService _authService = AuthService.instance;

  List<Report> _completedReports = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCompletedTasks();
  }

  Future<void> _loadCompletedTasks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('Worker not authenticated.');

      final reports = await _reportService.getAssignedReports(user.id);
      final resolved =
          reports.where((r) => r.status == ReportStatus.resolved).toList();

      if (!mounted) return;
      setState(() {
        _completedReports = resolved;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load completed tasks: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Completed Tasks',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_completedReports.length} complaints successfully resolved on site.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
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
                            onPressed: _loadCompletedTasks,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _completedReports.isEmpty
                      ? RefreshIndicator(
                          onRefresh: _loadCompletedTasks,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 80),
                              EmptyStateView(
                                icon: Icons.task_alt_rounded,
                                title: 'No completed tasks yet',
                                description:
                                    'Tasks you mark as Resolved in the field will be archived here for reference.',
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadCompletedTasks,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              20,
                              8,
                              20,
                              24,
                            ),
                            itemCount: _completedReports.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final report = _completedReports[index];

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
                                  _loadCompletedTasks();
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
