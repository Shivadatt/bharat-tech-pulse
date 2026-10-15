import '../../core/errors/app_exceptions.dart';
import '../models/author_model.dart';
import '../models/category_model.dart';
import '../models/tag_model.dart';
import '../services/mock_data_source.dart';
import 'category_repository.dart';

/// Concrete in-memory mock implementation of [CategoryRepository].
class MockCategoryRepository implements CategoryRepository {
  final List<CategoryModel> _categories = List.from(MockDataSource.categories);
  final List<AuthorModel> _authors = List.from(MockDataSource.authors);
  final List<TagModel> _tags = List.from(MockDataSource.tags);

  int _seq = 0;

  /// The CMS dialogs hand over rows with an empty id because Supabase assigns
  /// the primary key server-side. The mock lists are keyed by id exactly like
  /// the table, so storing several `''` rows makes every later update or delete
  /// land on whichever duplicate sits earliest in the list.
  String _nextId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

  @override
  Future<List<CategoryModel>> getCategories() async {
    await Future.delayed(const Duration(milliseconds: 30));
    return List.unmodifiable(_categories);
  }

  @override
  Future<List<CategoryModel>> getCategoriesForAdmin() async {
    await Future.delayed(const Duration(milliseconds: 30));
    return List.unmodifiable(_categories);
  }

  @override
  Future<List<AuthorModel>> getAuthorsForAdmin() async {
    await Future.delayed(const Duration(milliseconds: 30));
    return List.unmodifiable(_authors);
  }

  @override
  Future<CategoryModel?> getCategoryBySlug(String slug) async {
    await Future.delayed(const Duration(milliseconds: 30));
    try {
      return _categories.firstWhere((c) => c.slug == slug);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<AuthorModel>> getAuthors() async {
    await Future.delayed(const Duration(milliseconds: 30));
    return List.unmodifiable(_authors);
  }

  @override
  Future<AuthorModel?> getAuthorBySlug(String slug) async {
    await Future.delayed(const Duration(milliseconds: 30));
    try {
      return _authors.firstWhere((a) => a.slug == slug);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<TagModel>> getTags() async {
    await Future.delayed(const Duration(milliseconds: 30));
    return List.unmodifiable(_tags);
  }

  @override
  Future<CategoryModel> createCategory(CategoryModel category) async {
    await Future.delayed(const Duration(milliseconds: 30));
    if (_categories.any((c) => c.slug == category.slug)) {
      throw const ValidationException(
        'A category with this slug already exists.',
      );
    }
    final stored = category.id.isEmpty
        ? CategoryModel(
            id: _nextId('cat'),
            slug: category.slug,
            name: category.name,
            description: category.description,
            iconCode: category.iconCode,
            subcategories: category.subcategories,
            imageUrl: category.imageUrl,
            sortOrder: category.sortOrder,
            isActive: category.isActive,
            seoTitle: category.seoTitle,
            seoDescription: category.seoDescription,
          )
        : category;
    _categories.add(stored);
    return stored;
  }

  @override
  Future<bool> updateCategory(CategoryModel category) async {
    await Future.delayed(const Duration(milliseconds: 30));
    final index = _categories.indexWhere((c) => c.id == category.id);
    if (index == -1) return false;
    if (_categories.any(
        (c) => c.id != category.id && c.slug == category.slug)) {
      throw const ValidationException(
        'A category with this slug already exists.',
      );
    }
    _categories[index] = category;
    return true;
  }

  @override
  Future<bool> deleteCategory(String id) async {
    await Future.delayed(const Duration(milliseconds: 30));
    final before = _categories.length;
    _categories.removeWhere((c) => c.id == id);
    return _categories.length < before;
  }

  @override
  Future<TagModel> createTag(TagModel tag) async {
    await Future.delayed(const Duration(milliseconds: 30));
    if (_tags.any((t) => t.slug == tag.slug)) {
      throw const ValidationException('A tag with this slug already exists.');
    }
    final stored = tag.id.isEmpty
        ? TagModel(id: _nextId('tag'), slug: tag.slug, name: tag.name, count: tag.count)
        : tag;
    _tags.add(stored);
    return stored;
  }

  @override
  Future<bool> updateTag(TagModel tag) async {
    await Future.delayed(const Duration(milliseconds: 30));
    final index = _tags.indexWhere((t) => t.id == tag.id);
    if (index == -1) return false;
    if (_tags.any((t) => t.id != tag.id && t.slug == tag.slug)) {
      throw const ValidationException('A tag with this slug already exists.');
    }
    _tags[index] = tag;
    return true;
  }

  @override
  Future<bool> deleteTag(String id) async {
    await Future.delayed(const Duration(milliseconds: 30));
    final before = _tags.length;
    _tags.removeWhere((t) => t.id == id);
    return _tags.length < before;
  }

  @override
  Future<AuthorModel> createAuthor(AuthorModel author) async {
    await Future.delayed(const Duration(milliseconds: 30));
    if (_authors.any((a) => a.slug == author.slug)) {
      throw const ValidationException(
        'An author with this slug already exists.',
      );
    }
    final stored = author.id.isEmpty
        ? AuthorModel(
            id: _nextId('author'),
            slug: author.slug,
            name: author.name,
            role: author.role,
            bio: author.bio,
            avatarUrl: author.avatarUrl,
            twitter: author.twitter,
            linkedin: author.linkedin,
            email: author.email,
            isActive: author.isActive,
            linkedUserId: author.linkedUserId,
          )
        : author;
    _authors.add(stored);
    return stored;
  }

  @override
  Future<bool> updateAuthor(AuthorModel author) async {
    await Future.delayed(const Duration(milliseconds: 30));
    final index = _authors.indexWhere((a) => a.id == author.id);
    if (index == -1) return false;
    if (_authors.any((a) => a.id != author.id && a.slug == author.slug)) {
      throw const ValidationException(
        'An author with this slug already exists.',
      );
    }
    _authors[index] = author;
    return true;
  }

  @override
  Future<bool> deleteAuthor(String id) async {
    await Future.delayed(const Duration(milliseconds: 30));
    final before = _authors.length;
    _authors.removeWhere((a) => a.id == id);
    return _authors.length < before;
  }
}
