import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_item.dart';

class NotificationService extends ChangeNotifier {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _realtimeChannel;

  List<NotificationItem> _notifications = [];
  bool _isLoading = false;
  String? _currentUserId;

  List<NotificationItem> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get isLoading => _isLoading;

  void initForCurrentUser() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _currentUserId = null;
      _notifications = [];
      _realtimeChannel?.unsubscribe();
      _realtimeChannel = null;
      notifyListeners();
      return;
    }

    if (_currentUserId == user.id && _realtimeChannel != null) {
      // Already initialized for this user
      fetchNotifications();
      return;
    }

    _currentUserId = user.id;
    fetchNotifications();

    _realtimeChannel?.unsubscribe();
    _realtimeChannel = _supabase
        .channel('public:notifications:$_currentUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _currentUserId!,
          ),
          callback: (_) {
            fetchNotifications();
          },
        )
        .subscribe();
  }

  Future<List<NotificationItem>> fetchNotifications() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    _isLoading = true;
    notifyListeners();

    try {
      final res = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      _notifications = (res as List)
          .map((item) => NotificationItem.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return _notifications;
  }

  Future<void> markAsRead(String id) async {
    try {
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        notifyListeners();
      }

      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', id);
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      _notifications = _notifications
          .map((n) => n.copyWith(isRead: true))
          .toList();
      notifyListeners();

      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  Future<void> sendNotification({
    required String userId,
    String? reportId,
    required String title,
    required String message,
    String type = 'general',
  }) async {
    try {
      final payload = <String, dynamic>{
        'user_id': userId,
        'title': title,
        'message': message,
        'type': type,
        'is_read': false,
      };
      if (reportId != null) {
        payload['report_id'] = reportId;
      }
      await _supabase.from('notifications').insert(payload);
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  void disposeChannel() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
  }
}
