/// Category model representing main editorial sections and subcategories.
class CategoryModel {
  final String id;
  final String slug;
  final String name;
  final String description;
  final String iconCode;
  final List<String> subcategories;

  const CategoryModel({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.iconCode,
    required this.subcategories,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'name': name,
        'description': description,
        'icon_code': iconCode,
        'subcategories': subcategories,
      };

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
        id: json['id'] as String,
        slug: json['slug'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        iconCode: json['icon_code'] as String? ?? 'folder',
        subcategories: (json['subcategories'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );
}
