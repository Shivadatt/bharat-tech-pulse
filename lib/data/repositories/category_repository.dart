import '../models/author_model.dart';
import '../models/category_model.dart';
import '../models/tag_model.dart';

/// Abstract contract for Categories, Authors, and Tags data access.
abstract class CategoryRepository {
  Future<List<CategoryModel>> getCategories();
  Future<CategoryModel?> getCategoryBySlug(String slug);
  Future<List<AuthorModel>> getAuthors();
  Future<AuthorModel?> getAuthorBySlug(String slug);
  Future<List<TagModel>> getTags();

  // Admin / CRUD methods
  Future<CategoryModel> createCategory(CategoryModel category);
  Future<bool> updateCategory(CategoryModel category);
  Future<bool> deleteCategory(String id);
  Future<TagModel> createTag(TagModel tag);
  Future<bool> updateTag(TagModel tag);
  Future<bool> deleteTag(String id);
  Future<AuthorModel> createAuthor(AuthorModel author);
  Future<bool> updateAuthor(AuthorModel author);
  Future<bool> deleteAuthor(String id);
}
