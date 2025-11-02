# ErrorHandlingMixin - Part 2: Real-World Examples

Real-world examples from the Butlery codebase showing before/after migrations.

**Part of**: [error-handling-mixin](./error-handling-mixin.md) (split for readability)
**See also**: [Part 1: Basics](./error-handling-mixin-part1-basics.md), [Part 3: Migration](./error-handling-mixin-part3-migration.md)

## Real-World Examples

### Example 1: Simple Service (RecipeService)

**Before** (lib/services/recipe_service.dart - 60 lines):
```dart
class RecipeService {
  final RecipeRepository _repository;
  final Logger _logger;

  RecipeService({
    required RecipeRepository repository,
    required Logger logger,
  }) : _repository = repository,
       _logger = logger;

  Future<Recipe?> getRecipe(String id) async {
    try {
      _logger.info('Getting recipe: $id');
      final recipe = await _repository.getById(id);
      _logger.info('Recipe retrieved: $id');
      return recipe;
    } catch (e, stackTrace) {
      _logger.error('Failed to get recipe', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> updateRecipe(Recipe recipe) async {
    try {
      _logger.info('Updating recipe: ${recipe.id}');
      await _repository.update(recipe);
      _logger.info('Recipe updated: ${recipe.id}');
    } catch (e, stackTrace) {
      _logger.error('Failed to update recipe', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> deleteRecipe(String id) async {
    try {
      _logger.info('Deleting recipe: $id');
      await _repository.delete(id);
      _logger.info('Recipe deleted: $id');
    } catch (e, stackTrace) {
      _logger.error('Failed to delete recipe', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<List<Recipe>> searchRecipes(String query) async {
    try {
      _logger.info('Searching recipes: $query');
      final results = await _repository.search(query);
      _logger.info('Found ${results.length} recipes');
      return results;
    } catch (e, stackTrace) {
      _logger.error('Failed to search recipes', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
```

**After** (lib/services/recipe_service.dart - 25 lines):
```dart
class RecipeService extends BaseService {
  final RecipeRepository _repository;

  RecipeService({required RecipeRepository repository})
      : _repository = repository;

  @override
  String get serviceName => 'RecipeService';

  Future<Recipe?> getRecipe(String id) async {
    return await executeServiceOperation(
      () => _repository.getById(id),
      operationName: 'Get recipe',
    );
  }

  Future<void> updateRecipe(Recipe recipe) async {
    await executeServiceOperation(
      () => _repository.update(recipe),
      operationName: 'Update recipe',
    );
  }

  Future<void> deleteRecipe(String id) async {
    await executeServiceOperation(
      () => _repository.delete(id),
      operationName: 'Delete recipe',
    );
  }

  Future<List<Recipe>> searchRecipes(String query) async {
    return await executeServiceOperation(
      () => _repository.search(query),
      operationName: 'Search recipes',
      retryOnFailure: true,
    );
  }
}
```

**Saved**: 35 lines, consistent error handling, automatic logging

### Example 2: Service with Network Calls (ImageUploadService)

**Before** (lib/services/upload/image_upload_service.dart - 80 lines):
```dart
class ImageUploadService {
  final StorageRepository _storage;
  final Logger _logger;

  Future<String?> uploadImage(File image, String path) async {
    int retries = 0;
    const maxRetries = 3;

    while (retries < maxRetries) {
      try {
        _logger.info('Uploading image (attempt ${retries + 1}/$maxRetries)');
        final url = await _storage.uploadFile(image, path);
        _logger.info('Image uploaded successfully');
        return url;
      } on SocketException catch (e) {
        retries++;
        if (retries >= maxRetries) {
          _logger.error('Network error after $maxRetries attempts: $e');
          rethrow;
        }
        _logger.warning('Network error, retrying... (attempt $retries)');
        await Future.delayed(Duration(seconds: retries * 2));
      } catch (e, stackTrace) {
        _logger.error('Failed to upload image', error: e, stackTrace: stackTrace);
        rethrow;
      }
    }
    return null;
  }

  Future<void> deleteImage(String path) async {
    try {
      _logger.info('Deleting image: $path');
      await _storage.deleteFile(path);
      _logger.info('Image deleted successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to delete image', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<List<String>> uploadMultipleImages(List<File> images) async {
    final urls = <String>[];

    for (var i = 0; i < images.length; i++) {
      try {
        _logger.info('Uploading image ${i + 1} of ${images.length}');
        final url = await uploadImage(images[i], 'recipes/${Uuid().v4()}');
        if (url != null) {
          urls.add(url);
        }
      } catch (e) {
        _logger.error('Failed to upload image ${i + 1}, continuing...');
        // Continue with other images
      }
    }

    _logger.info('Uploaded ${urls.length} of ${images.length} images');
    return urls;
  }
}
```

**After** (lib/services/upload/image_upload_service.dart - 30 lines):
```dart
class ImageUploadService extends BaseService {
  final StorageRepository _storage;

  ImageUploadService({required StorageRepository storage})
      : _storage = storage;

  @override
  String get serviceName => 'ImageUploadService';

  Future<String?> uploadImage(File image, String path) async {
    return await executeServiceOperation(
      () => _storage.uploadFile(image, path),
      operationName: 'Upload image',
      retryOnFailure: true,
      maxRetries: 3,
    );
  }

  Future<void> deleteImage(String path) async {
    await executeServiceOperation(
      () => _storage.deleteFile(path),
      operationName: 'Delete image',
    );
  }

  Future<List<String>> uploadMultipleImages(List<File> images) async {
    final operations = images
        .map((img) => () => uploadImage(img, 'recipes/${Uuid().v4()}'))
        .toList();

    return await executeBatchOperation(
      operations,
      operationName: 'Upload multiple images',
      continueOnError: true,
    );
  }
}
```

**Saved**: 50 lines, automatic retry logic, cleaner batch operations

### Example 3: Service with CRUD Operations (MenuService)

**Before** (lib/services/menu_service.dart - 100 lines):
```dart
class MenuService {
  final MenuRepository _repository;
  final Logger _logger;

  Future<Menu> createMenu(Menu menu) async {
    try {
      _logger.info('Creating menu: ${menu.title}');

      // Validation
      if (menu.title.isEmpty) {
        throw ValidationException('Menu title is required');
      }

      final created = await _repository.create(menu);
      _logger.info('Menu created: ${created.id}');
      return created;
    } catch (e, stackTrace) {
      _logger.error('Failed to create menu', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<Menu?> getMenu(String id) async {
    try {
      _logger.info('Loading menu: $id');
      final menu = await _repository.getById(id);

      if (menu == null) {
        _logger.warning('Menu not found: $id');
        return null;
      }

      _logger.info('Menu loaded: $id');
      return menu;
    } catch (e, stackTrace) {
      _logger.error('Failed to load menu', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> updateMenu(Menu menu) async {
    try {
      _logger.info('Updating menu: ${menu.id}');

      // Validation
      if (menu.title.isEmpty) {
        throw ValidationException('Menu title is required');
      }

      // Check exists
      final existing = await _repository.getById(menu.id);
      if (existing == null) {
        throw NotFoundException('Menu not found: ${menu.id}');
      }

      await _repository.update(menu);
      _logger.info('Menu updated: ${menu.id}');
    } catch (e, stackTrace) {
      _logger.error('Failed to update menu', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> deleteMenu(String id) async {
    try {
      _logger.info('Deleting menu: $id');

      // Check exists
      final existing = await _repository.getById(id);
      if (existing == null) {
        throw NotFoundException('Menu not found: $id');
      }

      await _repository.delete(id);
      _logger.info('Menu deleted: $id');
    } catch (e, stackTrace) {
      _logger.error('Failed to delete menu', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
```

**After** (lib/services/menu_service.dart - 30 lines):
```dart
class MenuService extends BaseService {
  final MenuRepository _repository;

  MenuService({required MenuRepository repository})
      : _repository = repository;

  @override
  String get serviceName => 'MenuService';

  Future<Menu> createMenu(Menu menu) async {
    return await safeCreate(
      () => _repository.create(menu),
      'Menu',
    );
  }

  Future<Menu?> getMenu(String id) async {
    return await safeLoad(
      () => _repository.getById(id),
      'Menu',
      id,
    );
  }

  Future<void> updateMenu(Menu menu) async {
    await safeUpdate(
      () => _repository.update(menu),
      'Menu',
      menu.id,
    );
  }

  Future<void> deleteMenu(String id) async {
    await safeDelete(
      () => _repository.delete(id),
      'Menu',
      id,
    );
  }
}
```

**Saved**: 70 lines, automatic validation and logging

---

## Next Steps

Continue with:
- **[Part 3: Migration](./error-handling-mixin-part3-migration.md)** - Migration guide, priorities, and best practices

---

**Impact**: 35-70 lines saved per service
**Examples**: RecipeService, ImageUploadService, MenuService
**Status**: ✅ Production-ready patterns
