import 'package:flutter_test/flutter_test.dart';
import 'package:india_tech_web/core/errors/app_exceptions.dart';
import 'package:india_tech_web/core/errors/postgrest_error_mapper.dart';
import 'package:india_tech_web/core/supabase/role_permissions.dart';
import 'package:india_tech_web/core/utils/slug_generator.dart';
import 'package:india_tech_web/data/models/article_model.dart';
import 'package:india_tech_web/data/models/author_model.dart';
import 'package:india_tech_web/data/repositories/supabase_article_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Supabase mapping (pure, no network)', () {
    test('ArticleModel -> posts row -> ArticleModel round-trip incl. jsonb',
        () {
      const author = AuthorModel(
        id: 'a1',
        slug: 'priya-sharma',
        name: 'Priya Sharma',
        role: 'Senior Editor',
        bio: 'Tech journalist',
        avatarUrl: 'https://example.com/p.jpg',
        twitter: '@priya',
        linkedin: 'in/priya',
        email: 'priya@example.com',
      );

      final article = ArticleModel(
        id: 'p1',
        slug: 'best-ai-tools-2026',
        title: 'Best AI Tools 2026',
        excerpt: 'A curated list.',
        content: 'Full body content here.',
        categorySlug: 'ai',
        categoryName: 'AI & AI Tools',
        subcategory: 'Indic LLMs',
        tags: const ['ai-tools'],
        author: author,
        publishedAt: DateTime(2026, 10, 1, 12, 30),
        updatedAt: DateTime(2026, 10, 2, 9, 15),
        featuredImage: 'https://example.com/hero.jpg',
        readingTimeMinutes: 7,
        status: ArticleStatus.archived,
        isFeatured: true,
        isTrending: true,
        isPopular: false,
        viewCount: 42,
        keyTakeaways: const ['First point', 'Second point'],
        faqs: const [
          ArticleFaq(question: 'Is it free?', answer: 'Mostly, yes.'),
        ],
        toc: const [
          ArticleTocItem(id: 'intro', title: 'Introduction'),
        ],
      );

      // Model -> posts insert map.
      final insertMap = SupabaseArticleRepository.articleToInsertMap(
        article,
        siteId: 'site-1',
        categoryId: 'cat-1',
        authorId: 'a1',
      );
      expect(insertMap['site_id'], 'site-1');
      expect(insertMap['category_id'], 'cat-1');
      expect(insertMap['author_id'], 'a1');
      expect(insertMap['status'], 'archived');
      expect(insertMap['view_count'], 0);
      expect(insertMap['reading_time'], 7);
      expect(insertMap['key_takeaways'], ['First point', 'Second point']);
      expect((insertMap['faqs'] as List).single['question'], 'Is it free?');
      expect((insertMap['toc'] as List).single['id'], 'intro');

      // Simulate the DB echoing the row back with relational embeds joined.
      // `updated_at` and `view_count` are server-owned: the insert map never
      // sends them (view_count is forced to 0 on insert), so the echoed row
      // carries the trigger/db-generated values instead.
      final joinedRow = <String, dynamic>{
        ...insertMap,
        'id': 'p1',
        'view_count': 42,
        'updated_at': article.updatedAt.toIso8601String(),
        'categories': {'name': 'AI & AI Tools', 'slug': 'ai'},
        'authors': {
          'id': 'a1',
          'name': 'Priya Sharma',
          'slug': 'priya-sharma',
          'bio': 'Tech journalist',
          'avatar_url': 'https://example.com/p.jpg',
          'designation': 'Senior Editor',
          'social_links': {
            'twitter': '@priya',
            'linkedin': 'in/priya',
            'email': 'priya@example.com',
          },
        },
        'tags': [
          {'name': 'AI Tools', 'slug': 'ai-tools'},
        ],
      };

      final restored = SupabaseArticleRepository.rowToArticle(joinedRow);
      expect(restored.id, article.id);
      expect(restored.slug, article.slug);
      expect(restored.title, article.title);
      expect(restored.excerpt, article.excerpt);
      expect(restored.content, article.content);
      expect(restored.categorySlug, 'ai');
      expect(restored.categoryName, 'AI & AI Tools');
      expect(restored.subcategory, article.subcategory);
      expect(restored.tags, ['ai-tools']);
      expect(restored.author.name, author.name);
      expect(restored.author.role, author.role);
      expect(restored.author.twitter, '@priya');
      expect(restored.author.email, 'priya@example.com');
      expect(restored.publishedAt, article.publishedAt);
      expect(restored.updatedAt, article.updatedAt);
      expect(restored.featuredImage, article.featuredImage);
      expect(restored.readingTimeMinutes, 7);
      // archived must parse from the DB enum value.
      expect(restored.status, ArticleStatus.archived);
      expect(restored.isFeatured, true);
      expect(restored.isTrending, true);
      expect(restored.isPopular, false);
      // view_count is owned by the backend; mapping reads the server value
      // (the client only ever sends 0 on insert).
      expect(restored.viewCount, 42);
      expect(restored.keyTakeaways, article.keyTakeaways);
      expect(restored.faqs.single.question, 'Is it free?');
      expect(restored.faqs.single.answer, 'Mostly, yes.');
      expect(restored.toc.single.id, 'intro');
      expect(restored.toc.single.title, 'Introduction');
    });

    test('rowToArticle falls back to a blank author and published status',
        () {
      final row = SupabaseArticleRepository.rowToArticle({
        'id': 'p2',
        'slug': 'orphan-post',
        'title': 'Orphan',
        'published_at': '2026-10-01T00:00:00.000Z',
        'updated_at': '2026-10-01T00:00:00.000Z',
        'status': 'not_a_real_status',
        'authors': null,
      });
      expect(row.author.name, '');
      expect(row.status, ArticleStatus.published);
    });

    test('articleToUpdateMap always writes both foreign keys', () {
      final article = ArticleModel(
        id: 'p3',
        slug: 'edited-post',
        title: 'Edited',
        excerpt: 'Excerpt',
        content: 'Body',
        categorySlug: 'ai',
        categoryName: 'AI & AI Tools',
        subcategory: '',
        tags: const [],
        author: const AuthorModel(
          id: '',
          slug: '',
          name: '',
          role: '',
          bio: '',
          avatarUrl: '',
          twitter: '',
          linkedin: '',
          email: '',
        ),
        publishedAt: DateTime.utc(2026, 10, 1),
        updatedAt: DateTime.utc(2026, 10, 2),
        featuredImage: '',
        readingTimeMinutes: 4,
      );

      // Unresolvable slug -> explicit null, so a stale category/author from a
      // previous edit cannot survive the update.
      final cleared = SupabaseArticleRepository.articleToUpdateMap(article);
      expect(cleared.containsKey('category_id'), isTrue);
      expect(cleared['category_id'], isNull);
      expect(cleared.containsKey('author_id'), isTrue);
      expect(cleared['author_id'], isNull);

      final linked = SupabaseArticleRepository.articleToUpdateMap(
        article,
        categoryId: 'cat-1',
        authorId: 'author-1',
      );
      expect(linked['category_id'], 'cat-1');
      expect(linked['author_id'], 'author-1');
      // Server-owned / client-forbidden columns are never part of an update.
      expect(linked.containsKey('view_count'), isFalse);
      expect(linked.containsKey('site_id'), isFalse);
      expect(linked.containsKey('published_at'), isFalse);
    });
  });

  group('SlugGenerator', () {
    test('basic latin phrases', () {
      expect(SlugGenerator.generate('Hello World!'), 'hello-world');
    });

    test('collapses and trims separators', () {
      expect(SlugGenerator.generate('--a__b--'), 'a-b');
    });

    test('non-latin scripts cannot be slugified -> ValidationException', () {
      expect(
        () => SlugGenerator.generate('नमस्ते'),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('PostgrestErrorMapper', () {
    test('23505 unique violation -> friendly ValidationException', () {
      const error = PostgrestException(
        message:
            'duplicate key value violates unique constraint "categories_site_id_slug_key"',
        code: '23505',
      );
      final mapped = error.toAppException();
      expect(mapped, isA<ValidationException>());
      expect(
        mapped.message,
        'A record with this value already exists. Please use a unique value.',
      );
      // Raw Postgres detail must never reach the UI message.
      expect(mapped.message.contains('duplicate key'), isFalse);
    });

    test('42501 RLS violation -> friendly permission message', () {
      const error = PostgrestException(
        message: 'new row violates row-level security policy',
        code: '42501',
      );
      final mapped = error.toAppException();
      expect(mapped, isA<AppException>());
      expect(mapped.message, "You don't have permission to perform this action.");
      expect(mapped.message.contains('row-level security'), isFalse);
    });

    test('PGRST116 -> NotFoundException', () {
      const error = PostgrestException(
        message: 'The result contains 0 rows',
        code: 'PGRST116',
      );
      expect(error.toAppException(), isA<NotFoundException>());
    });

    test('unknown codes -> generic safe message', () {
      const error = PostgrestException(
        message: 'relation "public.posts" does not exist',
        code: '42P01',
      );
      final mapped = error.toAppException();
      expect(mapped.message, 'Something went wrong. Please try again.');
      expect(mapped.message.contains('public.posts'), isFalse);
    });
  });

  group('RolePermissions matrix', () {
    test('author is staff but cannot manage content or publish', () {
      expect(RolePermissions.isStaff(AdminRole.author), true);
      expect(RolePermissions.canManageContent(AdminRole.author), false);
      expect(RolePermissions.canPublish(AdminRole.author), false);
      expect(RolePermissions.canManageSettings(AdminRole.author), false);
    });

    test('editor can manage content and publish but not settings', () {
      expect(RolePermissions.canManageContent(AdminRole.editor), true);
      expect(RolePermissions.canPublish(AdminRole.editor), true);
      expect(RolePermissions.canManageSettings(AdminRole.editor), false);
    });

    test('admin can manage settings; super_admin can do everything', () {
      expect(RolePermissions.canManageSettings(AdminRole.admin), true);
      expect(RolePermissions.canManageContent(AdminRole.admin), true);
      expect(RolePermissions.canManageSettings(AdminRole.superAdmin), true);
      expect(RolePermissions.canPublish(AdminRole.superAdmin), true);
    });

    test('parse maps db strings and degrades unknown roles to author', () {
      expect(RolePermissions.parse('super_admin'), AdminRole.superAdmin);
      expect(RolePermissions.parse('admin'), AdminRole.admin);
      expect(RolePermissions.parse('editor'), AdminRole.editor);
      expect(RolePermissions.parse('author'), AdminRole.author);
      expect(RolePermissions.parse(null), AdminRole.author);
      expect(RolePermissions.parse('site_owner'), AdminRole.author);
    });
  });
}
