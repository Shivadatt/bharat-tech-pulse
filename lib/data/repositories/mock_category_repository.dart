import '../models/author_model.dart';
import '../models/category_model.dart';
import '../models/tag_model.dart';
import '../services/mock_data_source.dart';
import 'category_repository.dart';

/// Concrete in-memory mock implementation of [CategoryRepository].
class MockCategoryRepository implements CategoryRepository {
  @override
  Future<List<CategoryModel>> getCategories() async {
    await Future.delayed(const Duration(milliseconds: 30));
    return List.from(MockDataSource.categories);
  }

  @override
  Future<CategoryModel?> getCategoryBySlug(String slug) async {
    await Future.delayed(const Duration(milliseconds: 30));
    try {
      return MockDataSource.categories.firstWhere((c) => c.slug == slug);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<AuthorModel>> getAuthors() async {
    await Future.delayed(const Duration(milliseconds: 30));
    return List.from(MockDataSource.authors);
  }

  @override
  Future<AuthorModel?> getAuthorBySlug(String slug) async {
    await Future.delayed(const Duration(milliseconds: 30));
    try {
      return MockDataSource.authors.firstWhere((a) => a.slug == slug);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<TagModel>> getTags() async {
    await Future.delayed(const Duration(milliseconds: 30));
    return List.from(MockDataSource.tags);
  }
}
