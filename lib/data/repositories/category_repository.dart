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
}
