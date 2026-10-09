import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/postgrest_error_mapper.dart';
import '../../core/supabase/supabase_service.dart';
import '../models/profile_model.dart';
import 'profile_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseClient get _client => SupabaseService.client;

  @override
  Future<ProfileModel?> loadCurrentProfile() => guardPostgrest(() async {
        final user = _client.auth.currentUser;
        if (user == null) return null;
        final row = await _client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();
        return row == null ? null : ProfileModel.fromJson(row);
      });
}
