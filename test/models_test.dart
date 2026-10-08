import 'package:flutter_test/flutter_test.dart';
import 'package:india_tech_web/data/models/article_model.dart';
import 'package:india_tech_web/data/models/author_model.dart';
import 'package:india_tech_web/data/models/category_model.dart';

void main() {
  group('Data Models Tests', () {
    test('AuthorModel serialization & deserialization', () {
      const author = AuthorModel(
        id: 'auth-1',
        slug: 'test-author',
        name: 'Test Author',
        role: 'Editor',
        bio: 'Bio text',
        avatarUrl: 'https://example.com/avatar.jpg',
        twitter: '@test',
        linkedin: 'in/test',
        email: 'test@example.com',
      );

      final json = author.toJson();
      expect(json['id'], 'auth-1');
      expect(json['name'], 'Test Author');

      final fromJson = AuthorModel.fromJson(json);
      expect(fromJson.name, author.name);
      expect(fromJson.email, author.email);
    });

    test('CategoryModel serialization & deserialization', () {
      const category = CategoryModel(
        id: 'cat-ai',
        slug: 'ai',
        name: 'AI & AI Tools',
        description: 'Artificial intelligence updates',
        iconCode: 'psychology',
        subcategories: ['Indic LLMs', 'Vision'],
      );

      final json = category.toJson();
      expect(json['slug'], 'ai');
      expect(json['subcategories'].length, 2);

      final fromJson = CategoryModel.fromJson(json);
      expect(fromJson.name, category.name);
      expect(fromJson.subcategories.first, 'Indic LLMs');
    });

    test('ArticleModel copyWith & metadata', () {
      const author = AuthorModel(
        id: 'auth-1',
        slug: 'test-author',
        name: 'Test Author',
        role: 'Editor',
        bio: 'Bio',
        avatarUrl: '',
        twitter: '',
        linkedin: '',
        email: '',
      );

      final article = ArticleModel(
        id: 'art-1',
        slug: 'sarvam-ai-review',
        title: 'Sarvam AI Review',
        excerpt: 'Indic model breakdown',
        content: 'Body content',
        categorySlug: 'ai',
        categoryName: 'AI & Tools',
        subcategory: 'Indic LLMs',
        tags: ['sarvam', 'ai'],
        author: author,
        publishedAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 2),
        featuredImage: 'https://example.com/img.jpg',
        readingTimeMinutes: 5,
        isFeatured: true,
        viewCount: 1500,
      );

      expect(article.slug, 'sarvam-ai-review');
      expect(article.isFeatured, true);

      final updated = article.copyWith(title: 'Updated Title', viewCount: 2000);
      expect(updated.title, 'Updated Title');
      expect(updated.viewCount, 2000);
      expect(updated.slug, article.slug);
    });
  });
}
