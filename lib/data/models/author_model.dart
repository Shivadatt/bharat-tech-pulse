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
      );
}
