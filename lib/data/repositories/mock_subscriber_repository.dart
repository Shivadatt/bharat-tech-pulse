import '../../core/errors/app_exceptions.dart';
import '../models/subscriber_model.dart';
import 'subscriber_repository.dart';

/// In-memory subscriber list for mock mode and tests.
class MockSubscriberRepository implements SubscriberRepository {
  final List<SubscriberModel> _storage;

  MockSubscriberRepository([List<SubscriberModel>? seed])
      : _storage = seed != null ? List.of(seed) : List.of(_demoSeed);

  static final List<SubscriberModel> _demoSeed = [
    SubscriberModel(
      id: 'sub-1',
      email: 'asha.rao@example.com',
      name: 'Asha Rao',
      isVerified: true,
      subscribedAt: DateTime(2026, 9, 12),
    ),
    SubscriberModel(
      id: 'sub-2',
      email: 'vikram.menon@example.com',
      name: 'Vikram Menon',
      subscribedAt: DateTime(2026, 9, 28),
    ),
    SubscriberModel(
      id: 'sub-3',
      email: 'neri.patel@example.com',
      name: '',
      isActive: false,
      subscribedAt: DateTime(2026, 8, 30),
      unsubscribedAt: DateTime(2026, 9, 20),
    ),
  ];

  @override
  Future<List<SubscriberModel>> getSubscribers(
          {int limit = 50, int offset = 0}) async {
    await Future.delayed(const Duration(milliseconds: 30));
    if (offset >= _storage.length) return [];
    return _storage.skip(offset).take(limit).toList();
  }

  @override
  Future<int> countSubscribers() async => _storage.length;

  @override
  Future<SubscriberModel?> subscribe(String email, {String? name}) async {
    await Future.delayed(const Duration(milliseconds: 40));
    final trimmed = email.trim();
    if (!trimmed.contains('@') || trimmed.endsWith('@')) {
      throw const ValidationException('Please enter a valid email address.');
    }
    if (_storage.any((s) => s.email.toLowerCase() == trimmed.toLowerCase())) {
      return null;
    }
    final created = SubscriberModel(
      id: 'sub-${DateTime.now().microsecondsSinceEpoch}',
      email: trimmed,
      name: (name ?? '').trim(),
      subscribedAt: DateTime.now(),
    );
    _storage.insert(0, created);
    return created;
  }

  @override
  Future<bool> setActive(String id, bool isActive) async {
    final index = _storage.indexWhere((s) => s.id == id);
    if (index == -1) return false;
    final current = _storage[index];
    _storage[index] = SubscriberModel(
      id: current.id,
      email: current.email,
      name: current.name,
      isVerified: current.isVerified,
      isActive: isActive,
      subscribedAt: current.subscribedAt,
      unsubscribedAt:
          isActive ? null : DateTime.now(),
    );
    return true;
  }

  @override
  Future<bool> removeSubscriber(String id) async {
    final before = _storage.length;
    _storage.removeWhere((s) => s.id == id);
    return _storage.length < before;
  }
}
