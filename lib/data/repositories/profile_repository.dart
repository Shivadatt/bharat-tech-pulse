import '../models/profile_model.dart';

/// Abstract contract for the authenticated user's profile.
abstract class ProfileRepository {
  /// Loads the `profiles` row for the currently signed-in user, or null when
  /// no user is signed in / no profile row exists.
  Future<ProfileModel?> loadCurrentProfile();
}
