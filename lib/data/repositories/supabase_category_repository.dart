import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/postgrest_error_mapper.dart';
import '../../core/supabase/site_context.dart';
import '../../core/supabase/supabase_service.dart';
import '../models/author_model.dart';
import '../models/category_model.dart';
import '../models/tag_model.dart';
import 'category_repository.dart';

/// Supabase implementation of [CategoryRepository]. All reads are
/// site-scoped and duplicate slugs surface as friendly ValidationExceptions
/// via the 23505 mapping in [guardPostgrest].
class SupabaseCategoryRepository implements CategoryRepository {
  final SiteContext _site;
  SupabaseCategoryRepository({SiteContext? siteContext})
      : _site = siteContext ?? SiteContext();

  SupabaseClient get _client => SupabaseService.client;

  /// Maps an `authors` row; `social_links` jsonb flattens into the legacy
  /// twitter/linkedin/email fields.
  static AuthorModel rowToAuthor(Map<String, dynamic> row) {
    final social = row['social_links'];
    return AuthorModel(
      id: row['id'] as String? ?? '',
      slug: row['slug'] as String? ?? '',
      name: row['name'] as String? ?? '',
      role: row['designation'] as String? ?? 'Tech Writer',
      bio: row['bio'] as String? ?? '',
      avatarUrl: row['avatar_url'] as String? ?? '',
      twitter: social is Map ? (social['twitter'] as String? ?? '') : '',
      linkedin: social is Map ? (social['linkedin'] as String? ?? '') : '',
      email: social is Map ? (social['email'] as String? ?? '') : '',
    );
  }

  static Map<String, dynamic> authorToRow(
    AuthorModel author, {
    required String siteId,
    String? userId,
  }) {
    final row = <String, dynamic>{
      'site_id': siteId,
      'name': author.name,
      'slug': author.slug,
      'bio': author.bio,
      'avatar_url': author.avatarUrl,
      'designation': author.role,
      'social_links': {
        'twitter': author.twitter,
        'linkedin': author.linkedin,
        'email': author.email,
      },
      'is_active': true,
    };
    if (userId != null) row['user_id'] = userId;
    return row;
  }

  // ---------------------------------------------------------------------------
  // Public reads
  // ---------------------------------------------------------------------------

  @override
  Future<List<CategoryModel>> getCategories() => guardPostgrest(() async {
        final siteId = await _site.siteId;
        final rows = await _client
            .from('categories')
            .select()
            .eq('site_id', siteId)
            .eq('is_active', true)
            .order('sort_order', ascending: true);
        return rows.map((r) => CategoryModel.fromJson(r)).toList();
      });

  @override
  Future<CategoryModel?> getCategoryBySlug(String slug) =>
      guardPostgrest(() async {
        final siteId = await _site.siteId;
        final row = await _client
            .from('categories')
            .select()
            .eq('site_id', siteId)
            .eq('slug', slug)
            .maybeSingle();
        return row == null ? null : CategoryModel.fromJson(row);
      });

  @override
  Future<List<AuthorModel>> getAuthors() => guardPostgrest(() async {
        final siteId = await _site.siteId;
        final rows = await _client
            .from('authors')
            .select()
            .eq('site_id', siteId)
            .eq('is_active', true)
            .order('name', ascending: true);
        return rows.map((r) => rowToAuthor(r)).toList();
      });

  @override
  Future<AuthorModel?> getAuthorBySlug(String slug) => guardPostgrest(() async {
        final siteId = await _site.siteId;
        final row = await _client
            .from('authors')
            .select()
            .eq('site_id', siteId)
            .eq('slug', slug)
            .maybeSingle();
        return row == null ? null : rowToAuthor(row);
      });

  @override
  Future<List<TagModel>> getTags() => guardPostgrest(() async {
        final siteId = await _site.siteId;
        final rows = await _client
            .from('tags')
            .select()
            .eq('site_id', siteId)
            .order('name', ascending: true);
        return rows.map((r) => TagModel.fromJson(r)).toList();
      });

  // ---------------------------------------------------------------------------
  // Admin CRUD — Categories
  // ---------------------------------------------------------------------------

  @override
  Future<CategoryModel> createCategory(CategoryModel category) =>
      guardPostgrest(() async {
        final siteId = await _site.siteId;
        final row = await _client
            .from('categories')
            .insert({
              'site_id': siteId,
              'name': category.name,
              'slug': category.slug,
              'description': category.description,
              'icon_code': category.iconCode,
              'subcategories': category.subcategories,
              'is_active': true,
            })
            .select()
            .single();
        return CategoryModel.fromJson(row);
      });

  @override
  Future<bool> updateCategory(CategoryModel category) =>
      guardPostgrest(() async {
        final siteId = await _site.siteId;
        final rows = await _client
            .from('categories')
            .update({
              'name': category.name,
              'slug': category.slug,
              'description': category.description,
              'icon_code': category.iconCode,
              'subcategories': category.subcategories,
            })
            .eq('site_id', siteId)
            .eq('id', category.id)
            .select('id');
        return rows.isNotEmpty;
      });

  @override
  Future<bool> deleteCategory(String id) => guardPostgrest(() async {
        final siteId = await _site.siteId;
        final rows = await _client
            .from('categories')
            .delete()
            .eq('site_id', siteId)
            .eq('id', id)
            .select('id');
        return rows.isNotEmpty;
      });

  // ---------------------------------------------------------------------------
  // Admin CRUD — Tags
  // ---------------------------------------------------------------------------

  @override
  Future<TagModel> createTag(TagModel tag) => guardPostgrest(() async {
        final siteId = await _site.siteId;
        final row = await _client
            .from('tags')
            .insert({'site_id': siteId, 'name': tag.name, 'slug': tag.slug})
            .select()
            .single();
        return TagModel.fromJson(row);
      });

  @override
  Future<bool> updateTag(TagModel tag) => guardPostgrest(() async {
        final siteId = await _site.siteId;
        final rows = await _client
            .from('tags')
            .update({'name': tag.name, 'slug': tag.slug})
            .eq('site_id', siteId)
            .eq('id', tag.id)
            .select('id');
        return rows.isNotEmpty;
      });

  @override
  Future<bool> deleteTag(String id) => guardPostgrest(() async {
        final siteId = await _site.siteId;
        final rows = await _client
            .from('tags')
            .delete()
            .eq('site_id', siteId)
            .eq('id', id)
            .select('id');
        return rows.isNotEmpty;
      });

  // ---------------------------------------------------------------------------
  // Admin CRUD — Authors
  // ---------------------------------------------------------------------------

  @override
  Future<AuthorModel> createAuthor(AuthorModel author) =>
      guardPostgrest(() async {
        final siteId = await _site.siteId;
        final row = await _client
            .from('authors')
            .insert(authorToRow(author, siteId: siteId))
            .select()
            .single();
        return rowToAuthor(row);
      });

  @override
  Future<bool> updateAuthor(AuthorModel author) => guardPostgrest(() async {
        final siteId = await _site.siteId;
        final rows = await _client
            .from('authors')
            .update(authorToRow(author, siteId: siteId)
              ..remove('site_id')
              ..remove('user_id'))
            .eq('site_id', siteId)
            .eq('id', author.id)
            .select('id');
        return rows.isNotEmpty;
      });

  @override
  Future<bool> deleteAuthor(String id) => guardPostgrest(() async {
        final siteId = await _site.siteId;
        final rows = await _client
            .from('authors')
            .delete()
            .eq('site_id', siteId)
            .eq('id', id)
            .select('id');
        return rows.isNotEmpty;
      });
}
