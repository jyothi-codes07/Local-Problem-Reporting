class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.role,
    this.createdAt,
  });

  final String id;
  final String name;
  final String role;
  final DateTime? createdAt;

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'User',
      role: (map['role']?.toString() ?? 'citizen').toLowerCase(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
    );
  }
}
