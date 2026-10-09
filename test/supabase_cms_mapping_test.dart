import 'package:flutter_test/flutter_test.dart';
import 'package:india_tech_web/core/errors/app_exceptions.dart';
import 'package:india_tech_web/core/supabase/role_permissions.dart';
import 'package:india_tech_web/data/models/author_model.dart';
import 'package:india_tech_web/data/models/article_model.dart';
import 'package:india_tech_web/data/models/category_model.dart';
import 'package:india_tech_web/data/models/post_revision_model.dart';
import 'package:india_tech_web/data/models/profile_model.dart';
import 'package:india_tech_web/data/models/redirect_model.dart';
import 'package:india_tech_web/data/models/site_settings_model.dart';
import 'package:india_tech_web/data/models/subscriber_model.dart';
import 'package:india_tech_web/data/repositories/mock_category_repository.dart';
import 'package:india_tech_web/data/repositories/mock_redirect_repository.dart';
import 'package:india_tech_web/data/repositories/mock_subscriber_repository.dart';
import 'package:india_tech_web/data/repositories/supabase_analytics_repository.dart';
import 'package:india_tech_web/data/repositories/supabase_category_repository.dart';
import 'package:india_tech_web/data/repositories/supabase_post_admin_repository.dart';
import 'package:india_tech_web/data/repositories/supabase_profile_repository.dart';
import 'package:india_tech_web/data/repositories/supabase_redirect_repository.dart';
import 'package:india_tech_web/data/repositories/supabase_site_settings_repository.dart';
import 'package:india_tech_web/data/repositories/supabase_subscriber_repository.dart';

void main() {
  group('Site settings mapping (pure)', () {
    test('settingsToColumns omits site_id (server-scoped) and round-trips', () {
      const model = SiteSettingsModel(
        id: 'ss-1',
        siteName: 'Bharat Tech Pulse',
        tagline: 'Tech for everyday India',
        logoUrl: 'https://cdn/logo.png',
        faviconUrl: 'https://cdn/favicon.ico',
        defaultMetaTitle: 'Meta title',
        defaultMetaDescription: 'Meta description',
        contactEmail: 'editor@bharattechpulse.in',
        socialLinks: {'twitter': '@btp', 'linkedin': 'btp'},
        footerText: 'Footer',
        copyrightText: '© 2026',
        googleAnalyticsId: 'G-XYZ',
      );

      final columns = SupabaseSiteSettingsRepository.settingsToColumns(model);
      expect(columns.containsKey('site_id'), isFalse);
      expect(columns['site_name'], 'Bharat Tech Pulse');
      expect(columns['google_analytics_id'], 'G-XYZ');
      expect(columns['social_links'], {'twitter': '@btp', 'linkedin': 'btp'});

      final row = {...columns, 'id': 'ss-1', 'updated_at': '2026-10-01T00:00:00Z'};
      final restored = SupabaseSiteSettingsRepository.rowToSettings(row);
      expect(restored.id, 'ss-1');
      expect(restored.siteName, 'Bharat Tech Pulse');
      expect(restored.socialLinks['twitter'], '@btp');
      expect(restored.updatedAt, isNotNull);
    });

    test('social_links accepts an encoded jsonb string', () {
      final model = SiteSettingsModel.fromJson({
        'id': 'ss-2',
        'social_links': '{"telegram":"@btpnews"}',
      });
      expect(model.socialLinks['telegram'], '@btpnews');
    });
  });

  group('Subscriber mapping (pure)', () {
    test('anonymous insert pins verified/active and never trusts client', () {
      final columns = SupabaseSubscriberRepository.subscriberInsertColumns(
        'reader@example.com',
        '  Reader  ',
        siteId: 'site-1',
      );
      expect(columns['site_id'], 'site-1');
      expect(columns['email'], 'reader@example.com');
      expect(columns['name'], 'Reader');
      expect(columns['is_verified'], false);
      expect(columns['is_active'], true);
      expect(columns['unsubscribed_at'], isNull);
    });

    test('blank name stores null', () {
      final columns = SupabaseSubscriberRepository.subscriberInsertColumns(
        'a@b.co',
        '   ',
        siteId: 'site-1',
      );
      expect(columns['name'], isNull);
    });

    test('rowToSubscriber parses timestamps', () {
      final sub = SupabaseSubscriberRepository.rowToSubscriber({
        'id': 's1',
        'email': 'a@b.co',
        'is_active': false,
        'subscribed_at': '2026-09-01T10:00:00Z',
        'unsubscribed_at': '2026-09-20T10:00:00Z',
      });
      expect(sub.isActive, false);
      expect(sub.unsubscribedAt, isNotNull);
    });
  });

  group('Redirect mapping (pure)', () {
    test('redirectInsertColumns + rowToRedirect round-trip', () {
      final columns = SupabaseRedirectRepository.redirectInsertColumns(
        '/article/old',
        '/article/new',
        301,
        siteId: 'site-1',
      );
      expect(columns['old_path'], '/article/old');
      expect(columns['new_path'], '/article/new');
      expect(columns['status_code'], 301);

      final row = {...columns, 'id': 'r1', 'created_at': '2026-10-01T00:00:00Z'};
      final restored = SupabaseRedirectRepository.rowToRedirect(row);
      expect(restored.oldPath, '/article/old');
      expect(restored.statusCode, 301);
    });
  });

  group('Analytics mapping (pure)', () {
    test('event columns normalise empty strings to null', () {
      final columns = SupabaseAnalyticsRepository.eventInsertColumns(
        siteId: 'site-1',
        eventType: 'page_view',
        sessionId: 's-1',
        path: '',
        postId: 'post-1',
      );
      expect(columns['path'], isNull);
      expect(columns['referrer'], isNull);
      expect(columns['post_id'], 'post-1');
    });

    test('distinctSessions ignores blank session ids', () {
      final sessions = SupabaseAnalyticsRepository.distinctSessions([
        {'session_id': 'a'},
        {'session_id': 'a'},
        {'session_id': 'b'},
        {'session_id': ''},
        {'session_id': null},
      ]);
      expect(sessions, {'a', 'b'});
    });

    test('rowToTopPost reads the server view_count', () {
      final top = SupabaseAnalyticsRepository.rowToTopPost({
        'id': 'p1',
        'title': 'Hello',
        'slug': 'hello',
        'view_count': 123,
      });
      expect(top.viewCount, 123);
      expect(top.slug, 'hello');
    });
  });

  group('Post admin mapping (pure)', () {
    test('patchToColumns only touches lifecycle/flag columns', () {
      final columns = SupabasePostAdminRepository.patchToColumns(
        status: ArticleStatus.published,
        isTrending: true,
      );
      expect(columns['status'], 'published');
      expect(columns['is_trending'], true);
      expect(columns.containsKey('title'), isFalse);
      expect(columns.containsKey('content'), isFalse);
    });

    test('clearScheduledFor nulls the go-live time', () {
      final columns = SupabasePostAdminRepository.patchToColumns(
        clearScheduledFor: true,
      );
      expect(columns.containsKey('scheduled_for'), isTrue);
      expect(columns['scheduled_for'], isNull);
    });

    test('revision round-trip and view-count sum', () {
      final rev = PostRevisionModel(
        id: '',
        postId: 'p1',
        revisionNumber: 3,
        createdAt: DateTime(2026, 10, 1),
        title: 'T',
        content: 'C',
      );
      final columns =
          SupabasePostAdminRepository.revisionToColumns(rev, editedBy: 'u1');
      expect(columns['post_id'], 'p1');
      expect(columns['revision_number'], 3);
      expect(columns['edited_by'], 'u1');

      final restored = SupabasePostAdminRepository.rowToRevision({
        ...columns,
        'id': 'r1',
        'created_at': '2026-10-01T00:00:00Z',
      });
      expect(restored.revisionNumber, 3);

      expect(
        SupabasePostAdminRepository.sumViewCounts([
          {'view_count': 10},
          {'view_count': 5},
          {'view_count': null},
        ]),
        15,
      );
    });
  });

  group('Category/author/tag mapping (pure)', () {
    const author = AuthorModel(
      id: 'a1',
      slug: 'priya',
      name: 'Priya Sharma',
      role: 'Senior Editor',
      bio: 'Tech journalist',
      avatarUrl: 'https://cdn/p.jpg',
      twitter: '@priya',
      linkedin: 'in/priya',
      email: 'priya@example.com',
    );

    test('authorToRow scopes site_id and flattens social links', () {
      final row = SupabaseCategoryRepository.authorToRow(author,
          siteId: 'site-1', userId: 'user-1');
      expect(row['site_id'], 'site-1');
      expect(row['designation'], 'Senior Editor');
      expect(row['user_id'], 'user-1');
      expect((row['social_links'] as Map)['email'], 'priya@example.com');
    });

    test('author round-trips through the row map', () {
      final row = SupabaseCategoryRepository.authorToRow(author,
          siteId: 'site-1');
      final restored = SupabaseCategoryRepository.rowToAuthor(row);
      expect(restored.name, author.name);
      expect(restored.role, author.role);
      expect(restored.twitter, author.twitter);
      expect(restored.email, author.email);
    });

    test('rowToTag reads the post_tags aggregate embed', () {
      final tag = SupabaseCategoryRepository.rowToTag({
        'id': 't1',
        'slug': 'ai',
        'name': 'AI',
        'post_tags': [
          {'count': 7},
        ],
      });
      expect(tag.count, 7);
    });

    test('categoryToRow never sends site_id or server timestamps', () {
      const cat = CategoryModel(
        id: 'c1',
        slug: 'ai',
        name: 'AI & AI Tools',
        description: 'd',
        iconCode: 'brain',
        subcategories: ['LLM'],
      );
      final row = SupabaseCategoryRepository.categoryToRow(cat);
      expect(row.containsKey('site_id'), isFalse);
      expect(row['subcategories'], ['LLM']);
    });
  });

  group('(site_id, site_role) resolution', () {
    test('siteRoleFromRow ignores inactive memberships', () {
      expect(
        SupabaseProfileRepository.siteRoleFromRow(
            {'role': 'editor', 'is_active': true}),
        'editor',
      );
      expect(
        SupabaseProfileRepository.siteRoleFromRow(
            {'role': 'editor', 'is_active': false}),
        isNull,
      );
    });

    test('effective role: super_admin global wins, else the site role', () {
      expect(
        RolePermissions.resolveEffective(
            globalRole: 'super_admin', siteRole: 'author'),
        AdminRole.superAdmin,
      );
      expect(
        RolePermissions.resolveEffective(globalRole: 'member', siteRole: 'editor'),
        AdminRole.editor,
      );
      expect(
        RolePermissions.resolveEffective(globalRole: 'member', siteRole: null),
        AdminRole.author,
      );
    });

    test('a reader with no profile_sites row has no site access', () {
      expect(
        RolePermissions.hasSiteAccess(globalRole: 'member', siteRole: null),
        isFalse,
      );
      expect(
        RolePermissions.hasSiteAccess(globalRole: 'member', siteRole: 'author'),
        isTrue,
      );

      final reader = ProfileModel.fromJson(
        {'id': 'p1', 'email': 'x@y.z', 'role': 'member', 'is_active': true},
        siteRole: null,
      );
      expect(reader.hasSiteAccess, isFalse);
      expect(reader.effectiveRole, AdminRole.author);
      expect(RolePermissions.canManageContent(reader.effectiveRole), isFalse);
    });
  });

  group('Admin repository reads (in-memory mocks, no network)', () {
    test('MockCategoryRepository admin reads include every row', () async {
      final repo = MockCategoryRepository();
      final cats = await repo.getCategoriesForAdmin();
      final authors = await repo.getAuthorsForAdmin();
      expect(cats.length, 8);
      expect(authors.length >= 4, true);
      // Archived/inactive rows surface for admin even though public reads hide them.
      expect(cats.every((c) => c.id.isNotEmpty), isTrue);
    });

    test('MockRedirectRepository validates paths and dedupes by oldPath',
        () async {
      final repo = MockRedirectRepository();
      await expectLater(repo.createRedirect('/a', '/a'),
          throwsA(isA<ValidationException>()));
      await expectLater(repo.createRedirect('no-slash', '/b'),
          throwsA(isA<ValidationException>()));
      final created = await repo.createRedirect('/old', '/new');
      expect(created, isA<RedirectModel>());
      expect(await repo.createRedirect('/old', '/other'), isNull);
    });

    test('MockSubscriberRepository enforces unique email and shape', () async {
      final repo = MockSubscriberRepository([
        SubscriberModel(id: 's1', email: 'dup@x.com', subscribedAt: DateTime(2026)),
      ]);
      await expectLater(repo.subscribe('bad-email'),
          throwsA(isA<ValidationException>()));
      expect(await repo.subscribe('dup@x.com'), isNull);
      final fresh = await repo.subscribe('new@x.com', name: 'New');
      expect(fresh?.email, 'new@x.com');
      expect(await repo.countSubscribers(), 2);
    });
  });
}
