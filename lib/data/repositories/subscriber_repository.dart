import '../models/subscriber_model.dart';

/// Contract for newsletter subscribers. Anyone may [subscribe]; only site
/// editors and above can list, change or remove subscribers (RLS).
abstract class SubscriberRepository {
  /// Admin-only read. Throws an authorization [AppException] for callers
  /// without a site membership that can read subscriber emails.
  Future<List<SubscriberModel>> getSubscribers({int limit = 50, int offset = 0});

  Future<int> countSubscribers();

  /// Returns the stored row, or null when [email] was already subscribed.
  Future<SubscriberModel?> subscribe(String email, {String? name});

  Future<bool> setActive(String id, bool isActive);

  Future<bool> removeSubscriber(String id);
}
