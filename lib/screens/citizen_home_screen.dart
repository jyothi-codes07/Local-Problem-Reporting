import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/report.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/report_service.dart';
import '../widgets/app_header.dart';
import '../widgets/report_card.dart';
import '../widgets/section_header.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'report_details_screen.dart';

class CitizenHomeScreen extends StatefulWidget {
  const CitizenHomeScreen({
    super.key,
    required this.onReportTap,
    required this.onSeeAllReports,
    required this.onCategoryTap,
    this.onNotificationTap,
    this.onProfileTap,
  });

  final VoidCallback onReportTap;
  final VoidCallback onSeeAllReports;
  final ValueChanged<ReportCategory> onCategoryTap;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;

  @override
  State<CitizenHomeScreen> createState() => _CitizenHomeScreenState();
}

class _CitizenHomeScreenState extends State<CitizenHomeScreen> {
  final ReportService _reportService = ReportService();
  final AuthService _authService = AuthService.instance;

  UserProfile? _profile;
  List<Report> _myReports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _reportService.addListener(_loadData);
    _loadData();
  }

  @override
  void dispose() {
    _reportService.removeListener(_loadData);
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_myReports.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final profile = await _authService.getCurrentProfile();
      final reports = await _reportService.getMyReports();

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _myReports = reports;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    final displayName = _profile?.name ?? 'Demo Citizen';
    final activeCount = _myReports
        .where((r) =>
            r.status == ReportStatus.reported ||
            r.status == ReportStatus.underReview ||
            r.status == ReportStatus.assigned)
        .length;
    final inProgressCount =
        _myReports.where((r) => r.status == ReportStatus.inProgress).length;
    final resolvedCount =
        _myReports.where((r) => r.status == ReportStatus.resolved).length;
    final recentReports = _myReports.take(4).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top section with greeting, avatar & notifications
                AppHeader(
                  title: 'LocalFix',
                  subtitle: '$greeting, $displayName · Ward 12',
                  profile: _profile,
                  onNotificationTap: _openNotifications,
                  onProfileTap: _openProfile,
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HERO CARD
                      _CitizenHeroCard(onReportTap: widget.onReportTap),
                      const SizedBox(height: 18),

                      // ACTIVE REPORTS SUMMARY
                      _ReportSummarySection(
                        activeCount: activeCount,
                        inProgressCount: inProgressCount,
                        resolvedCount: resolvedCount,
                        onSeeAll: widget.onSeeAllReports,
                      ),
                      const SizedBox(height: 22),

                      // CATEGORY SHORTCUTS
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Report by category',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Ward 12 Services',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.outline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 104,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: ReportCategory.values.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final category = ReportCategory.values[index];
                            return _CategoryCard(
                              category: category,
                              onTap: () => widget.onCategoryTap(category),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      // RECENT REPORTS
                      SectionHeader(
                        title: 'Recent reports',
                        actionLabel: _myReports.length > 3 ? 'See all' : null,
                        onAction: widget.onSeeAllReports,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
            )
          else if (recentReports.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.assignment_outlined,
                        size: 36,
                        color: scheme.outline,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No complaints reported yet',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Spotted a pothole, broken streetlight, or garbage pile? Tap "REPORT A PROBLEM" above to submit your first report.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
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

class _CitizenHeroCard extends StatelessWidget {
  const _CitizenHeroCard({required this.onReportTap});

  final VoidCallback onReportTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.dark,
            AppColors.primary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, color: AppColors.accent, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Ward 12 Civic Action',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'See a problem?\nHelp fix your community.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.25,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Report potholes, broken lights, garbage, or water leaks directly to city crews.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onReportTap,
              icon: const Icon(Icons.add_location_alt_rounded, size: 18),
              label: const Text(
                'REPORT A PROBLEM',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.dark,
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportSummarySection extends StatelessWidget {
  const _ReportSummarySection({
    required this.activeCount,
    required this.inProgressCount,
    required this.resolvedCount,
    required this.onSeeAll,
  });

  final int activeCount;
  final int inProgressCount;
  final int resolvedCount;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.07),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryPill(
              label: 'Active',
              count: activeCount,
              color: AppColors.warning,
              icon: Icons.hourglass_top_rounded,
            ),
          ),
          Container(
            width: 1,
            height: 32,
            color: Colors.black.withValues(alpha: 0.08),
          ),
          Expanded(
            child: _SummaryPill(
              label: 'In Progress',
              count: inProgressCount,
              color: AppColors.info,
              icon: Icons.engineering_rounded,
            ),
          ),
          Container(
            width: 1,
            height: 32,
            color: Colors.black.withValues(alpha: 0.08),
          ),
          Expanded(
            child: _SummaryPill(
              label: 'Resolved',
              count: resolvedCount,
              color: AppColors.success,
              icon: Icons.check_circle_outline_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String label;
  final int count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.onTap});

  final ReportCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      width: 106,
      height: 104,
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    iconForCategory(category),
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const Spacer(),
                Text(
                  category.shortLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
