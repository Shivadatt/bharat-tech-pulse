import '../../core/supabase/role_permissions.dart';
import '../models/profile_model.dart';
import 'profile_repository.dart';

/// In-memory [ProfileRepository] used when no backend is configured.
class MockProfileRepository implements ProfileRepository {
  final ProfileModel? _profile;

  MockProfileRepository({ProfileModel? profile})
      : _profile = profile ??
            const ProfileModel(
              id: 'mock-profile-1',
              email: 'editor@bharattechpulse.test',
              fullName: 'Demo Editor',
              role: AdminRole.admin,
              siteRole: AdminRole.admin,
              isActive: true,
            );

  @override
  Future<ProfileModel?> loadCurrentProfile() async {
    await Future.delayed(const Duration(milliseconds: 30));
    return _profile;
  }
}
