/// Tag model for granular topic indexing.
class TagModel {
  final String id;
  final String slug;
  final String name;
  final int count;

  const TagModel({
    required this.id,
    required this.slug,
    required this.name,
    this.count = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'name': name,
        'count': count,
      };

  factory TagModel.fromJson(Map<String, dynamic> json) => TagModel(
        id: json['id'] as String,
        slug: json['slug'] as String,
        name: json['name'] as String,
        count: json['count'] as int? ?? 0,
      );
}
