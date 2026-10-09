import '../models/redirect_model.dart';

/// Contract for the `redirects` map. Public read, member write, admin manage.
abstract class RedirectRepository {
  Future<List<RedirectModel>> getRedirects({int limit = 50, int offset = 0});

  /// Returns the stored row, or null when [oldPath] already has a mapping.
  Future<RedirectModel?> createRedirect(
    String oldPath,
    String newPath, {
    int statusCode = 301,
  });

  Future<bool> deleteRedirect(String id);
}
