/// CMS roles mirrored from the Postgres `app_role` enum
/// ('super_admin','admin','editor','author').
enum AdminRole { superAdmin, admin, editor, author }

/// Capability matrix for the editorial CMS. Server-side RLS remains the
/// ultimate enforcement; this drives UI gating only.
class RolePermissions {
  RolePermissions._();

  /// Parses a database role string. Unknown/missing roles safely fall back
  /// to the least-privileged [AdminRole.author].
  static AdminRole parse(String? role) {
    switch (role) {
      case 'super_admin':
        return AdminRole.superAdmin;
      case 'admin':
        return AdminRole.admin;
      case 'editor':
        return AdminRole.editor;
      case 'author':
        return AdminRole.author;
      default:
        return AdminRole.author;
    }
  }

  /// Every authenticated profile with an app_role is CMS staff (as opposed
  /// to anonymous site visitors or newsletter subscribers).
  static bool isStaff(AdminRole role) => true;

  /// Editors and above can create/edit content.
  static bool canManageContent(AdminRole role) =>
      role == AdminRole.superAdmin ||
      role == AdminRole.admin ||
      role == AdminRole.editor;

  /// Only admins and above can touch site settings, users and SEO globals.
  static bool canManageSettings(AdminRole role) =>
      role == AdminRole.superAdmin || role == AdminRole.admin;

  /// Editors and above may publish (authors can only submit drafts).
  static bool canPublish(AdminRole role) =>
      role == AdminRole.superAdmin ||
      role == AdminRole.admin ||
      role == AdminRole.editor;
}
