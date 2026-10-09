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
  String? _siteId;

  SiteContext([SupabaseClient? client]) : _client = client ?? SupabaseService.client;

  Future<String> get siteId async {
    final cached = _siteId;
    if (cached != null) return cached;
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
    final id = row['id'] as String;
    _siteId = id;
    return id;
  }
}
