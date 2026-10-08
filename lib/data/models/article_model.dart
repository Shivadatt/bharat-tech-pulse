import 'author_model.dart';

class ArticleFaq {
  final String question;
  final String answer;

  const ArticleFaq({required this.question, required this.answer});

  Map<String, dynamic> toJson() => {'question': question, 'answer': answer};

  factory ArticleFaq.fromJson(Map<String, dynamic> json) => ArticleFaq(
        question: json['question'] as String? ?? '',
        answer: json['answer'] as String? ?? '',
      );
}

class ArticleTocItem {
  final String id;
  final String title;

  const ArticleTocItem({required this.id, required this.title});

  Map<String, dynamic> toJson() => {'id': id, 'title': title};

  factory ArticleTocItem.fromJson(Map<String, dynamic> json) => ArticleTocItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
      );
}

/// Core article entity model.
class ArticleModel {
  final String id;
  final String slug;
  final String title;
  final String excerpt;
  final String content;
  final String categorySlug;
  final String categoryName;
  final String subcategory;
  final List<String> tags;
  final AuthorModel author;
  final DateTime publishedAt;
  final DateTime updatedAt;
  final String featuredImage;
  final int readingTimeMinutes;
  final bool isFeatured;
  final bool isTrending;
  final bool isPopular;
  final int viewCount;
  final List<String> keyTakeaways;
  final List<ArticleFaq> faqs;
  final List<ArticleTocItem> toc;

  const ArticleModel({
    required this.id,
    required this.slug,
    required this.title,
    required this.excerpt,
    required this.content,
    required this.categorySlug,
    required this.categoryName,
    required this.subcategory,
    required this.tags,
    required this.author,
    required this.publishedAt,
    required this.updatedAt,
    required this.featuredImage,
    required this.readingTimeMinutes,
    this.isFeatured = false,
    this.isTrending = false,
    this.isPopular = false,
    this.viewCount = 0,
    this.keyTakeaways = const [],
    this.faqs = const [],
    this.toc = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'title': title,
        'excerpt': excerpt,
        'content': content,
        'category_slug': categorySlug,
        'category_name': categoryName,
        'subcategory': subcategory,
        'tags': tags,
        'author': author.toJson(),
        'published_at': publishedAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'featured_image': featuredImage,
        'reading_time_minutes': readingTimeMinutes,
        'is_featured': isFeatured,
        'is_trending': isTrending,
        'is_popular': isPopular,
        'view_count': viewCount,
        'key_takeaways': keyTakeaways,
        'faqs': faqs.map((f) => f.toJson()).toList(),
        'toc': toc.map((t) => t.toJson()).toList(),
      };

  factory ArticleModel.fromJson(Map<String, dynamic> json) => ArticleModel(
        id: json['id'] as String,
        slug: json['slug'] as String,
        title: json['title'] as String,
        excerpt: json['excerpt'] as String,
        content: json['content'] as String,
        categorySlug: json['category_slug'] as String,
        categoryName: json['category_name'] as String,
        subcategory: json['subcategory'] as String? ?? '',
        tags: (json['tags'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        author: AuthorModel.fromJson(json['author'] as Map<String, dynamic>),
        publishedAt: DateTime.parse(json['published_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        featuredImage: json['featured_image'] as String,
        readingTimeMinutes: json['reading_time_minutes'] as int? ?? 5,
        isFeatured: json['is_featured'] as bool? ?? false,
        isTrending: json['is_trending'] as bool? ?? false,
        isPopular: json['is_popular'] as bool? ?? false,
        viewCount: json['view_count'] as int? ?? 0,
        keyTakeaways: (json['key_takeaways'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        faqs: (json['faqs'] as List<dynamic>?)
                ?.map((e) => ArticleFaq.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        toc: (json['toc'] as List<dynamic>?)
                ?.map((e) => ArticleTocItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );

  ArticleModel copyWith({
    String? id,
    String? slug,
    String? title,
    String? excerpt,
    String? content,
    String? categorySlug,
    String? categoryName,
    String? subcategory,
    List<String>? tags,
    AuthorModel? author,
    DateTime? publishedAt,
    DateTime? updatedAt,
    String? featuredImage,
    int? readingTimeMinutes,
    bool? isFeatured,
    bool? isTrending,
    bool? isPopular,
    int? viewCount,
    List<String>? keyTakeaways,
    List<ArticleFaq>? faqs,
    List<ArticleTocItem>? toc,
  }) {
    return ArticleModel(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      title: title ?? this.title,
      excerpt: excerpt ?? this.excerpt,
      content: content ?? this.content,
      categorySlug: categorySlug ?? this.categorySlug,
      categoryName: categoryName ?? this.categoryName,
      subcategory: subcategory ?? this.subcategory,
      tags: tags ?? this.tags,
      author: author ?? this.author,
      publishedAt: publishedAt ?? this.publishedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      featuredImage: featuredImage ?? this.featuredImage,
      readingTimeMinutes: readingTimeMinutes ?? this.readingTimeMinutes,
      isFeatured: isFeatured ?? this.isFeatured,
      isTrending: isTrending ?? this.isTrending,
      isPopular: isPopular ?? this.isPopular,
      viewCount: viewCount ?? this.viewCount,
      keyTakeaways: keyTakeaways ?? this.keyTakeaways,
      faqs: faqs ?? this.faqs,
      toc: toc ?? this.toc,
    );
  }
}
