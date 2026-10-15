import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/config/site_config.dart';
import '../errors/app_exceptions.dart';
import 'supabase_service.dart';

/// Lazily resolves and caches the numeric/string site primary key for the
/// current deployment (slug from [SiteConfig.siteId]). Every repository
/// scopes its queries through this lookup.
class SiteContext {
  static const Duration _lookupTimeout = Duration(seconds: 10);

  final SupabaseClient _client;
  Future<String>? _siteIdFuture;

  SiteContext([SupabaseClient? client]) : _client = client ?? SupabaseService.client;

  /// Cached as the [Future], not as the value: `HomeController.loadHomeData`
  /// fans out ten concurrent repository reads, and a value cache lets every one
  /// of them observe `null` and dispatch its own `sites` lookup.
  Future<String> get siteId => _siteIdFuture ??= _resolveSiteId();

  Future<String> _resolveSiteId() async {
    try {
      return await _lookupSiteId();
    } catch (_) {
      // A failed lookup must not be memoised forever, or one transient network
      // error poisons every later read for the rest of the session.
      _siteIdFuture = null;
      rethrow;
    }
  }

  Future<String> _lookupSiteId() async {
    // Bounded so an unreachable host surfaces as an error instead of leaving
    // every dependent loading state spinning forever.
    final Map<String, dynamic>? row;
    try {
      row = await _client
          .from('sites')
          .select('id')
          .eq('slug', SiteConfig.siteId)
          .maybeSingle()
          .timeout(_lookupTimeout);
    } on TimeoutException {
      throw AppException(
        'Backend did not respond within ${_lookupTimeout.inSeconds}s.',
        details: 'site lookup: ${SiteConfig.siteId}',
      );
    }
    if (row == null) {
      throw NotFoundException(
        'Site "${SiteConfig.siteId}" is not provisioned in the backend.',
      );
    }
    return row['id'] as String;
  }
}
