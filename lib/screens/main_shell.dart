import 'package:flutter/material.dart';

import '../models/report.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/report_service.dart';
import 'authority_dashboard_screen.dart';
import 'authority_reports_screen.dart';
import 'citizen_home_screen.dart';
import 'my_reports_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'report_problem_screen.dart';
import 'worker_completed_screen.dart';
import 'worker_dashboard_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.role,
  });

  final String role;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  ReportCategory? _draftCategory;

  @override
  void initState() {
    super.initState();
    // Initialize profile and realtime notifications
    AuthService.instance.getCurrentProfile();
    NotificationService.instance.initForCurrentUser();
  }

  void _goTo(int index, {ReportCategory? category}) {
    setState(() {
      _index = index;
      if (category != null) {
        _draftCategory = category;
      }
    });
    if (_role == 'citizen' && index == 2) {
      ReportService.instance.notifyReportsChanged();
    }
  }

  String get _role => widget.role.toLowerCase();

  List<Widget> get _pages {
    switch (_role) {
      case 'authority':
        return [
          AuthorityDashboardScreen(
            onNotificationTap: () => _goTo(2),
            onProfileTap: () => _goTo(3),
            onViewAllReports: () => _goTo(1),
          ),
          const AuthorityReportsScreen(),
          const NotificationsScreen(),
          const ProfileScreen(),
        ];

      case 'worker':
        return [
          WorkerDashboardScreen(
            onNotificationTap: () => _goTo(2),
            onProfileTap: () => _goTo(3),
            onCompletedTabTap: () => _goTo(1),
          ),
          const WorkerCompletedScreen(),
          const NotificationsScreen(),
          const ProfileScreen(),
        ];

      default:
        return [
          CitizenHomeScreen(
            onReportTap: () => _goTo(1),
            onSeeAllReports: () => _goTo(2),
            onCategoryTap: (category) => _goTo(1, category: category),
            onNotificationTap: () => _goTo(3),
          ),
          ReportProblemScreen(
            initialCategory: _draftCategory,
            onSubmitted: () => _goTo(2),
          ),
          const MyReportsScreen(),
          const NotificationsScreen(),
        ];
    }
  }

  Widget _buildNotifIcon({required bool selected}) {
    return ListenableBuilder(
      listenable: NotificationService.instance,
      builder: (context, _) {
        final unread = NotificationService.instance.unreadCount;
        return Badge(
          isLabelVisible: unread > 0,
          label: Text(unread > 9 ? '9+' : '$unread'),
          child: Icon(
            selected
                ? Icons.notifications_rounded
                : Icons.notifications_outlined,
          ),
        );
      },
    );
  }

  List<NavigationDestination> get _navigationDestinations {
    switch (_role) {
      case 'authority':
        return [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Operations',
          ),
          const NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment_rounded),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: _buildNotifIcon(selected: false),
            selectedIcon: _buildNotifIcon(selected: true),
            label: 'Notifications',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ];

      case 'worker':
        return [
          const NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment_rounded),
            label: 'Tasks',
          ),
          const NavigationDestination(
            icon: Icon(Icons.task_alt_outlined),
            selectedIcon: Icon(Icons.task_alt_rounded),
            label: 'Completed',
          ),
          NavigationDestination(
            icon: _buildNotifIcon(selected: false),
            selectedIcon: _buildNotifIcon(selected: true),
            label: 'Notifications',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ];

      default:
        return [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            selectedIcon: Icon(Icons.add_box_rounded),
            label: 'Report',
          ),
          const NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt_rounded),
            label: 'My Reports',
          ),
          NavigationDestination(
            icon: _buildNotifIcon(selected: false),
            selectedIcon: _buildNotifIcon(selected: true),
            label: 'Notifications',
          ),
        ];
    }
  }

  List<NavigationRailDestination> get _railDestinations {
    final dests = _navigationDestinations;
    return dests
        .map(
          (d) => NavigationRailDestination(
            icon: d.icon,
            selectedIcon: d.selectedIcon,
            label: Text(d.label),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;

        if (isWide) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _index,
                    onDestinationSelected: (idx) => _goTo(idx),
                    labelType: NavigationRailLabelType.all,
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Icon(
                        Icons.location_city_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 32,
                      ),
                    ),
                    destinations: _railDestinations,
                  ),
                  const VerticalDivider(thickness: 1, width: 1),
                  Expanded(
                    child: IndexedStack(
                      index: _index,
                      children: _pages,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: SafeArea(
            child: IndexedStack(
              index: _index,
              children: _pages,
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (idx) => _goTo(idx),
            destinations: _navigationDestinations,
          ),
        );
      },
    );
  }
}