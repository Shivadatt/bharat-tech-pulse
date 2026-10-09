import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/errors/postgrest_error_mapper.dart';
import '../../core/supabase/site_context.dart';
import '../../core/supabase/supabase_service.dart';
import '../models/subscriber_model.dart';
import 'subscriber_repository.dart';

/// Supabase implementation of [SubscriberRepository].
///
/// Insert is the only anonymous write allowed by RLS, and it is
/// value-constrained (`is_verified = false`, `is_active = true`,
/// `unsubscribed_at is null`) — [subscriberInsertColumns] encodes exactly
/// that so a public signup can never self-verify.
class SupabaseSubscriberRepository implements SubscriberRepository {
  static final RegExp _emailPattern =
      RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

  final SiteContext _site;
  SupabaseSubscriberRepository({SiteContext? siteContext})
      : _site = siteContext ?? SiteContext();

  SupabaseClient get _client => SupabaseService.client;

  static Map<String, dynamic> subscriberInsertColumns(
    String email,
    String? name, {
    required String siteId,
  }) =>
      {
        'site_id': siteId,
        'email': email,
        'name': (name ?? '').trim().isEmpty ? null : name!.trim(),
        'is_verified': false,
        'is_active': true,
        'unsubscribed_at': null,
      };

  static SubscriberModel rowToSubscriber(Map<String, dynamic> row) =>
      SubscriberModel.fromJson(row);

  @override
  Future<List<SubscriberModel>> getSubscribers(
          {int limit = 50, int offset = 0}) =>
      guardPostgrest(() async {
        final siteId = await _site.siteId;
        final rows = await _client
            .from('subscribers')
            .select()
            .eq('site_id', siteId)
            .order('subscribed_at', ascending: false)
            .range(offset, offset + limit - 1);
        return rows.map((r) => rowToSubscriber(r)).toList();
      });

  @override
  Future<int> countSubscribers() => guardPostgrest(() async {
        final siteId = await _site.siteId;
        return _client
            .from('subscribers')
            .count(CountOption.exact)
            .eq('site_id', siteId);
      });

  @override
  Future<SubscriberModel?> subscribe(String email, {String? name}) =>
      guardPostgrest(() async {
        final trimmed = email.trim();
        if (!_emailPattern.hasMatch(trimmed)) {
          throw const ValidationException('Please enter a valid email address.');
        }
        final siteId = await _site.siteId;
        try {
          final row = await _client
              .from('subscribers')
              .insert(subscriberInsertColumns(trimmed, name, siteId: siteId))
              .select()
              .single();
          return rowToSubscriber(row);
        } on PostgrestException catch (e) {
          // Unique (site_id, email): an existing reader is simply re-thanked.
          if (e.code == '23505') return null;
          throw mapPostgrestException(e);
        }
      });

  @override
  Future<bool> setActive(String id, bool isActive) => guardPostgrest(() async {
        final siteId = await _site.siteId;
        final rows = await _client
            .from('subscribers')
            .update({
              'is_active': isActive,
              'unsubscribed_at':
                  isActive ? null : DateTime.now().toUtc().toIso8601String(),
            })
            .eq('site_id', siteId)
            .eq('id', id)
            .select('id');
        return rows.isNotEmpty;
      });

  @override
  Future<bool> removeSubscriber(String id) => guardPostgrest(() async {
        final siteId = await _site.siteId;
        final rows = await _client
            .from('subscribers')
            .delete()
            .eq('site_id', siteId)
            .eq('id', id)
            .select('id');
        return rows.isNotEmpty;
      });
}
