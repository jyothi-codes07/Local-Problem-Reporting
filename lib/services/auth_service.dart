import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../screens/login_screen.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final SupabaseClient _supabase = Supabase.instance.client;
  UserProfile? _currentProfile;

  User? get currentUser => _supabase.auth.currentUser;
  String? get currentUserId => currentUser?.id;
  UserProfile? get currentProfile => _currentProfile;

  Future<UserProfile?> getCurrentProfile({bool forceRefresh = false}) async {
    final user = currentUser;
    if (user == null) {
      _currentProfile = null;
      return null;
    }

    if (!forceRefresh && _currentProfile != null && _currentProfile!.id == user.id) {
      return _currentProfile;
    }

    try {
      final res = await _supabase
          .from('profiles')
          .select('id, name, role, created_at')
          .eq('id', user.id)
          .maybeSingle();

      if (res != null) {
        _currentProfile = UserProfile.fromMap(Map<String, dynamic>.from(res));
      } else {
        _currentProfile = UserProfile(
          id: user.id,
          name: user.email?.split('@').first ?? 'Citizen',
          role: 'citizen',
        );
      }
    } catch (_) {
      _currentProfile ??= UserProfile(
        id: user.id,
        name: user.email?.split('@').first ?? 'Citizen',
        role: 'citizen',
      );
    }

    return _currentProfile;
  }

  Future<List<UserProfile>> getWorkers() async {
    try {
      final res = await _supabase
          .from('profiles')
          .select('id, name, role, created_at')
          .eq('role', 'worker')
          .order('name');

      return (res as List)
          .map((item) => UserProfile.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('Error loading workers: $e');
      return [];
    }
  }

  Future<UserProfile?> getFirstAuthority() async {
    try {
      final res = await _supabase
          .from('profiles')
          .select('id, name, role, created_at')
          .eq('role', 'authority')
          .limit(1)
          .maybeSingle();

      if (res != null) {
        return UserProfile.fromMap(Map<String, dynamic>.from(res));
      }
    } catch (e) {
      debugPrint('Error getting authority profile: $e');
    }
    return null;
  }

  Future<void> signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm sign out'),
        content: const Text('Are you sure you want to sign out of LocalFix?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('SignOut error: $e');
    }

    _currentProfile = null;

    if (!context.mounted) return;

    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}
