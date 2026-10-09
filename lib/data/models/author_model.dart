/// Author model representing editorial contributors.
class AuthorModel {
  final String id;
  final String slug;
  final String name;
  final String role;
  final String bio;
  final String avatarUrl;
  final String twitter;
  final String linkedin;
  final String email;
  final bool isActive;

  /// `authors.user_id`: the auth account linked to this byline, when an
  /// operator has connected a writer to a login.
  final String? linkedUserId;

  const AuthorModel({
    required this.id,
    required this.slug,
    required this.name,
    required this.role,
    required this.bio,
    required this.avatarUrl,
    required this.twitter,
    required this.linkedin,
    required this.email,
    this.isActive = true,
    this.linkedUserId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'name': name,
        'role': role,
        'bio': bio,
        'avatar_url': avatarUrl,
        'twitter': twitter,
        'linkedin': linkedin,
        'email': email,
        'is_active': isActive,
        'user_id': linkedUserId,
      };

  factory AuthorModel.fromJson(Map<String, dynamic> json) => AuthorModel(
        id: json['id'] as String,
        slug: json['slug'] as String,
        name: json['name'] as String,
        role: json['role'] as String? ?? 'Tech Writer',
        bio: json['bio'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String? ?? '',
        twitter: json['twitter'] as String? ?? '',
        linkedin: json['linkedin'] as String? ?? '',
        email: json['email'] as String? ?? '',
        isActive: json['is_active'] as bool? ?? true,
      );

  AuthorModel copyWith({bool? isActive}) => AuthorModel(
        id: id,
        slug: slug,
        name: name,
        role: role,
        bio: bio,
        avatarUrl: avatarUrl,
        twitter: twitter,
        linkedin: linkedin,
        email: email,
        isActive: isActive ?? this.isActive,
        linkedUserId: linkedUserId,
      );
}
