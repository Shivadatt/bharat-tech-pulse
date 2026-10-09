/// One newsletter subscriber row. Emails are private: only site editors and
/// above can read this table (enforced by RLS).
class SubscriberModel {
  final String id;
  final String email;
  final String name;
  final bool isVerified;
  final bool isActive;
  final DateTime subscribedAt;
  final DateTime? unsubscribedAt;

  const SubscriberModel({
    required this.id,
    required this.email,
    this.name = '',
    this.isVerified = false,
    this.isActive = true,
    required this.subscribedAt,
    this.unsubscribedAt,
  });

  factory SubscriberModel.fromJson(Map<String, dynamic> json) =>
      SubscriberModel(
        id: json['id'] as String? ?? '',
        email: json['email'] as String? ?? '',
        name: json['name'] as String? ?? '',
        isVerified: json['is_verified'] as bool? ?? false,
        isActive: json['is_active'] as bool? ?? true,
        subscribedAt: DateTime.tryParse(json['subscribed_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        unsubscribedAt:
            DateTime.tryParse(json['unsubscribed_at']?.toString() ?? ''),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'is_verified': isVerified,
        'is_active': isActive,
        'subscribed_at': subscribedAt.toIso8601String(),
        'unsubscribed_at': unsubscribedAt?.toIso8601String(),
      };
}
