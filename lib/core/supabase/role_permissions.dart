/// CMS roles mirrored from the Postgres `app_role` enum
/// ('super_admin','admin','editor','author').
enum AdminRole { superAdmin, admin, editor, author }

/// Capability matrix for the editorial CMS. Server-side RLS remains the
/// ultimate enforcement; this drives UI gating only.
class RolePermissions {
  RolePermissions._();

  /// Ordering of the tiers: superAdmin > admin > editor > author.
  ///
  /// Written out instead of relying on [AdminRole.index] so reordering the enum
  /// cannot silently invert the matrix.
  static int rank(AdminRole role) {
    switch (role) {
      case AdminRole.superAdmin:
        return 3;
      case AdminRole.admin:
        return 2;
      case AdminRole.editor:
        return 1;
      case AdminRole.author:
        return 0;
    }
  }

  /// True when [role] holds at least the powers of [minimum]. The super_admin
  /// tier ranks highest, so it always wins.
  static bool isAtLeast(AdminRole role, AdminRole minimum) =>
      rank(role) >= rank(minimum);

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

  /// Editors and above can create/edit content. Mirrors `is_site_editor(...)`
  /// on `categories` (and the media library).
  static bool canManageContent(AdminRole role) =>
      isAtLeast(role, AdminRole.editor);

  /// Only admins and above can touch site settings, bylines ("authors" rows),
  /// users and SEO globals. Mirrors `is_site_admin(...)` on `site_settings` and
  /// `authors`.
  static bool canManageSettings(AdminRole role) =>
      isAtLeast(role, AdminRole.admin);

  /// Editors and above may publish (authors can only submit drafts).
  static bool canPublish(AdminRole role) => isAtLeast(role, AdminRole.editor);

  /// Mirror of the `is_site_admin(...)` RLS predicates: hard deletes of
  /// content, taxonomy, authors, redirects, site settings and subscribers.
  /// Media is deliberately NOT here — `media_delete_site_editor` lets editors
  /// remove assets, so the media button gates on [canManageContent].
  static bool canDeleteRecords(AdminRole role) =>
      isAtLeast(role, AdminRole.admin);

  /// Mirror of `is_site_editor(...)`: reading subscriber emails and analytics.
  static bool canViewReports(AdminRole role) => canManageContent(role);

  /// Effective CMS role: the global `super_admin` tier always wins, otherwise
  /// the caller's `profile_sites` role for the active site decides. A caller
  /// with no active membership has no site access at all — [resolvesTo] keeps
  /// that distinguishable from a plain `author` member.
  static AdminRole resolveEffective({
    required String? globalRole,
    required String? siteRole,
  }) {
    if (globalRole == 'super_admin') return AdminRole.superAdmin;
    return parse(siteRole);
  }

  /// True only when the caller actually holds a role on the active site
  /// (membership row, or the global super_admin tier).
  static bool hasSiteAccess({
    required String? globalRole,
    required String? siteRole,
  }) =>
      globalRole == 'super_admin' || siteRole != null;
}
