import '../../core/supabase/role_permissions.dart';

/// Authenticated user's row from the `profiles` table, enriched with the
/// caller's `profile_sites` role for the active site.
class ProfileModel {
  final String id;
  final String email;
  final String fullName;
  final String? avatarUrl;

  /// `profiles.role` — only `super_admin` is meaningful; every other value is
  /// inert until a `profile_sites` membership grants a site-scoped role.
  final AdminRole role;

  /// `profile_sites.role` for the active site; null when not a member.
  final AdminRole? siteRole;
  final bool isActive;

  const ProfileModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.avatarUrl,
    required this.role,
    required this.isActive,
    this.siteRole,
  });

  /// Effective CMS role for the active site.
  AdminRole get effectiveRole => role == AdminRole.superAdmin
      ? AdminRole.superAdmin
      : (siteRole ?? AdminRole.author);

  /// True only when the caller can act on the active site at all.
  bool get hasSiteAccess =>
      role == AdminRole.superAdmin || siteRole != null;

  factory ProfileModel.fromJson(
    Map<String, dynamic> json, {
    String? siteRole,
  }) =>
      ProfileModel(
        id: json['id'] as String? ?? '',
        email: json['email'] as String? ?? '',
        fullName: json['full_name'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
        // Unknown roles degrade to the least-privileged role instead of
        // crashing the admin shell.
        role: RolePermissions.parse(json['role'] as String?),
        siteRole: siteRole == null ? null : RolePermissions.parse(siteRole),
        isActive: json['is_active'] as bool? ?? false,
      );

  ProfileModel copyWith({AdminRole? siteRole}) => ProfileModel(
        id: id,
        email: email,
        fullName: fullName,
        avatarUrl: avatarUrl,
        role: role,
        siteRole: siteRole ?? this.siteRole,
        isActive: isActive,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'avatar_url': avatarUrl,
        'role': _roleName,
        'site_role': siteRole == null ? null : _enumToName(siteRole!),
        'is_active': isActive,
      };

  String get _roleName => _enumToName(role);

  static String _enumToName(AdminRole value) {
    switch (value) {
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

