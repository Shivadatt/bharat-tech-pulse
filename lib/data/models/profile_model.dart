import '../../core/supabase/role_permissions.dart';

/// Authenticated user's row from the `profiles` table.
class ProfileModel {
  final String id;
  final String email;
  final String fullName;
  final String? avatarUrl;
  final AdminRole role;
  final bool isActive;

  const ProfileModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.avatarUrl,
    required this.role,
    required this.isActive,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) => ProfileModel(
        id: json['id'] as String? ?? '',
        email: json['email'] as String? ?? '',
        fullName: json['full_name'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
        // Unknown roles degrade to the least-privileged role instead of
        // crashing the admin shell.
        role: RolePermissions.parse(json['role'] as String?),
        isActive: json['is_active'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'avatar_url': avatarUrl,
        'role': _roleName,
        'is_active': isActive,
      };

  String get _roleName {
    switch (role) {
      case AdminRole.superAdmin:
        return 'super_admin';
      case AdminRole.admin:
        return 'admin';
      case AdminRole.editor:
        return 'editor';
      case AdminRole.author:
        return 'author';
    }
  }
}
