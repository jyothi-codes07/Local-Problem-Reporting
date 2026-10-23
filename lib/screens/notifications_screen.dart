import 'package:flutter/material.dart';

import '../models/notification_item.dart';
import '../services/notification_service.dart';
import '../services/report_service.dart';
import '../widgets/empty_state.dart';
import 'report_details_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    this.showBackButton = false,
  });

  final bool showBackButton;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService.instance;
  final ReportService _reportService = ReportService();

  @override
  void initState() {
    super.initState();
    _notificationService.fetchNotifications();
  }

  Future<void> _handleNotificationTap(NotificationItem notification) async {
    if (!notification.isRead) {
      await _notificationService.markAsRead(notification.id);
    }

    if (notification.reportId != null && mounted) {
      final report = await _reportService.getReportById(notification.reportId!);
      if (report != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ReportDetailsScreen(report: report),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.showBackButton,
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          ListenableBuilder(
            listenable: _notificationService,
            builder: (context, _) {
              final unread = _notificationService.unreadCount;
              if (unread == 0) return const SizedBox.shrink();

              return TextButton.icon(
                onPressed: () => _notificationService.markAllAsRead(),
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('Mark all read'),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _notificationService,
        builder: (context, _) {
          if (_notificationService.isLoading &&
              _notificationService.notifications.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final notifications = _notificationService.notifications;

          if (notifications.isEmpty) {
            return RefreshIndicator(
              onRefresh: _notificationService.fetchNotifications,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 100),
                  EmptyStateView(
                    icon: Icons.notifications_none_rounded,
                    title: 'No notifications yet',
                    description:
                        'Updates about your reported complaints, assignments, and status changes will appear here.',
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _notificationService.fetchNotifications,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: notifications.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = notifications[index];
                return _NotificationTile(
                  item: item,
                  onTap: () => _handleNotificationTap(item),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.onTap,
  });

  final NotificationItem item;
  final VoidCallback onTap;

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'work_started':
      case 'started':
        return Icons.build_rounded;
      case 'assignment':
        return Icons.engineering_rounded;
      case 'resolution':
        return Icons.verified_rounded;
      case 'status_update':
        return Icons.track_changes_rounded;
      case 'new_report':
        return Icons.report_problem_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _colorForType(String type, ColorScheme scheme) {
    switch (type.toLowerCase()) {
      case 'work_started':
      case 'started':
        return const Color(0xFFD97706);
      case 'assignment':
        return const Color(0xFF175CD3);
      case 'resolution':
        return const Color(0xFF067647);
      case 'status_update':
        return const Color(0xFFB54708);
      case 'new_report':
        return scheme.primary;
      default:
        return scheme.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = _colorForType(item.type, scheme);

    return Card(
      elevation: 0,
      color: item.isRead
          ? scheme.surfaceContainerLowest
          : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: item.isRead
              ? scheme.outlineVariant.withValues(alpha: 0.3)
              : scheme.primary.withValues(alpha: 0.3),
          width: item.isRead ? 1 : 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconForType(item.type),
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: item.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                              color: item.isRead
                                  ? scheme.onSurface
                                  : scheme.onSurface,
                            ),
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDate(item.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}';
    }
  }
}
