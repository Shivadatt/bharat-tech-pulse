/// Per-site role facts resolved from `profiles` (global tier) plus
/// `profile_sites` (site-scoped tier).
class SiteRoleMembership {
  /// `profiles.role` — only `super_admin` carries meaning here.
  final String globalRole;

  /// `profile_sites.role` for the active site, null when the caller has no
  /// active membership on this site.
  final String? siteRole;

  final bool isSiteActive;

  const SiteRoleMembership({
    required this.globalRole,
    this.siteRole,
    this.isSiteActive = true,
  });

  static const SiteRoleMembership none =
      SiteRoleMembership(globalRole: '', siteRole: null);
}
