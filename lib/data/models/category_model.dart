/// Category model representing main editorial sections and subcategories.
class CategoryModel {
  final String id;
  final String slug;
  final String name;
  final String description;
  final String iconCode;
  final List<String> subcategories;
  final String imageUrl;
  final int sortOrder;
  final bool isActive;
  final String seoTitle;
  final String seoDescription;

  const CategoryModel({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.iconCode,
    required this.subcategories,
    this.imageUrl = '',
    this.sortOrder = 0,
    this.isActive = true,
    this.seoTitle = '',
    this.seoDescription = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'name': name,
        'description': description,
        'icon_code': iconCode,
        'subcategories': subcategories,
        'image_url': imageUrl,
        'sort_order': sortOrder,
        'is_active': isActive,
        'seo_title': seoTitle,
        'seo_description': seoDescription,
      };

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
        id: json['id'] as String? ?? '',
        slug: json['slug'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        iconCode: json['icon_code'] as String? ?? 'folder',
        subcategories: (json['subcategories'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        imageUrl: json['image_url'] as String? ?? '',
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        isActive: json['is_active'] as bool? ?? true,
        seoTitle: json['seo_title'] as String? ?? '',
        seoDescription: json['seo_description'] as String? ?? '',
      );
}
