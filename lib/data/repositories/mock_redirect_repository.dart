import '../../core/errors/app_exceptions.dart';
import '../models/redirect_model.dart';
import 'redirect_repository.dart';

class MockRedirectRepository implements RedirectRepository {
  /// Same shape rule the Supabase implementation enforces: paths must start
  /// with "/" and contain no spaces.
  static final RegExp _pathPattern = RegExp(r'^/[^\s]*$');

  final List<RedirectModel> _storage = [
    RedirectModel(
      id: 'redir-1',
      oldPath: '/article/old-slug',
      newPath: '/article/new-slug',
      createdAt: DateTime(2026, 9, 1),
    ),
  ];

  @override
  Future<List<RedirectModel>> getRedirects(
          {int limit = 50, int offset = 0}) async {
    // Supabase orders this list `created_at desc`.
    final sorted = List<RedirectModel>.from(_storage)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.skip(offset).take(limit).toList();
  }

  @override
  Future<RedirectModel?> createRedirect(
    String oldPath,
    String newPath, {
    int statusCode = 301,
  }) async {
    final from = oldPath.trim();
    final to = newPath.trim();
    if (!_pathPattern.hasMatch(from) || !_pathPattern.hasMatch(to)) {
      throw const ValidationException(
        'Redirect paths must start with "/" and contain no spaces.',
      );
    }
    if (from == to) {
      throw const ValidationException('A redirect cannot point at itself.');
    }
    if (statusCode != 301 && statusCode != 302 && statusCode != 307) {
      throw const ValidationException('Status code must be 301, 302 or 307.');
    }
    if (_storage.any((r) => r.oldPath == from)) return null;
    final created = RedirectModel(
      id: 'redir-${DateTime.now().microsecondsSinceEpoch}',
      oldPath: from,
      newPath: to,
      statusCode: statusCode,
      createdAt: DateTime.now(),
    );
    _storage.insert(0, created);
    return created;
  }

  @override
  Future<bool> deleteRedirect(String id) async {
    final before = _storage.length;
    _storage.removeWhere((r) => r.id == id);
    return _storage.length < before;
  }
}
