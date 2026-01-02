/// Backup and restore service for recipe export/import with cross-platform file operations and duplicate detection.
import 'dart:convert';
import 'dart:io';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';

class BackupService extends BaseService {
  @override
  String get serviceName => 'BackupService';

  Future<BackupResult> exportToFile() async {
    try {
      final recipeService = ServiceLocator.get<UnifiedRecipeService>();
      final recipes = recipeService.recipes;

      if (recipes.isEmpty) {
        return BackupResult.error('Inga recept att exportera');
      }

      final jsonData = {
        'butlery_backup': {
          'version': '1.0',
          'exported_at': DateTime.now().toIso8601String(),
          'user_id': FirebaseAuthRepository().currentUser?.uid,
          'recipe_count': recipes.length,
          'recipes': recipes.map((r) => r.toJson()).toList(),
        },
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);

      final timestamp = DateTime.now();
      final filename =
          'butlery_backup_${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}_${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}.json';

      if (Platform.isAndroid) {
        return await _saveToAndroidDownloads(
          jsonString,
          filename,
          recipes.length,
        );
      } else if (Platform.isIOS) {
        return await _saveToIOSDocuments(jsonString, filename, recipes.length);
      } else {
        return BackupResult.error('Plattformen stöds inte');
      }
    } catch (e) {
      AppLogger.error('Export misslyckades', e);
      return BackupResult.error('Export misslyckades: $e');
    }
  }

  Future<BackupResult> _saveToAndroidDownloads(
    String content,
    String filename,
    int recipeCount,
  ) async {
    try {
      Directory? directory;

      try {
        final List<Directory>? dirs = await getExternalStorageDirectories(
          type: StorageDirectory.downloads,
        );
        if (dirs != null && dirs.isNotEmpty) {
          String path = dirs.first.path;
          final androidIndex = path.indexOf('/Android');
          if (androidIndex != -1) {
            path = '${path.substring(0, androidIndex)}/Download';
          }
          directory = Directory(path);
        }
      } catch (e) {
        directory = await getExternalStorageDirectory();
      }
      if (directory == null) {
        return BackupResult.error('Kunde inte hitta lagringsmapp');
      }

      final butleryDir = Directory('${directory.path}/Butlery');
      if (!await butleryDir.exists()) {
        await butleryDir.create(recursive: true);
      }

      final file = File('${butleryDir.path}/$filename');
      await file.writeAsString(content);

      AppLogger.success('Backup sparad: ${file.path}');

      return BackupResult.success(
        message: 'Backup sparad i Android/data/.../Butlery',
        filePath: file.path,
        recipeCount: recipeCount,
      );
    } catch (e) {
      AppLogger.error('Kunde inte spara till Android', e);
      return BackupResult.error('Kunde inte spara fil: $e');
    }
  }

  Future<BackupResult> _saveToIOSDocuments(
    String content,
    String filename,
    int recipeCount,
  ) async {
    try {
      final directory = await getApplicationDocumentsDirectory();

      final butleryDir = Directory('${directory.path}/Butlery');
      if (!await butleryDir.exists()) {
        await butleryDir.create(recursive: true);
      }

      final file = File('${butleryDir.path}/$filename');
      await file.writeAsString(content);

      AppLogger.success('Backup sparad: ${file.path}');

      return BackupResult.success(
        message: 'Backup sparad i Filer-appen',
        filePath: file.path,
        recipeCount: recipeCount,
      );
    } catch (e) {
      AppLogger.error('Kunde inte spara till iOS', e);
      return BackupResult.error('Kunde inte spara fil: $e');
    }
  }

  Future<ImportResult> importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return ImportResult.cancelled();
      }

      final file = result.files.first;

      if (file.bytes == null) {
        return ImportResult.error('Kunde inte läsa filen');
      }

      final jsonString = utf8.decode(file.bytes!);
      final jsonData = json.decode(jsonString);

      if (!jsonData.containsKey('butlery_backup') &&
          !jsonData.containsKey('butlery_export')) {
        return ImportResult.error('Ogiltig backup-fil - inte från Butlery');
      }

      // Backward compatibility: support both legacy and current format
      final backupData =
          jsonData['butlery_backup'] ?? jsonData['butlery_export'];
      final recipesJson = backupData['recipes'] as List;

      final recipeService = ServiceLocator.get<UnifiedRecipeService>();
      int successCount = 0;
      int skipCount = 0;
      final errors = <String>[];
      final skippedTitles = <String>[];

      for (final recipeJson in recipesJson) {
        try {
          final recipe = Recipe.fromJson(recipeJson);

          final existingRecipes = recipeService.recipes;
          final alreadyExists = existingRecipes.any(
            (r) => r.title.toLowerCase() == recipe.title.toLowerCase(),
          );

          if (alreadyExists) {
            skipCount++;
            skippedTitles.add(recipe.title);
            continue;
          }

          final newRecipe = Recipe(
            core: RecipeCore(
              id: '',
              title: recipe.title,
              description: recipe.description,
              ingredients: recipe.ingredients,
              instructions: recipe.instructions,
              imageUrls: recipe.imageUrls,
              mealType: recipe.mealType,
              portions: recipe.portions,
              timeMinutes: recipe.timeMinutes,
              rating: recipe.rating,
              personalTagIds: recipe.personalTagIds,
              sourceUrl:
                  'Importerat från backup ${_formatDate(DateTime.now())}',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              createdBy: '',
            ),
            type: RecipeType.personal,
          );

          await recipeService.personal.createRecipe(
            title: newRecipe.title,
            description: newRecipe.description,
            ingredients: newRecipe.ingredients,
            instructions: newRecipe.instructions,
            imageUrls: newRecipe.imageUrls,
            mealType: newRecipe.mealType,
            portions: newRecipe.portions,
            timeMinutes: newRecipe.timeMinutes,
            rating: newRecipe.rating,
            personalTagIds: newRecipe.personalTagIds,
            sourceUrl: newRecipe.sourceUrl,
          );
          successCount++;
        } catch (e) {
          skipCount++;
          errors.add('${recipeJson['title'] ?? 'Okänt recept'}: $e');
        }
      }

      return ImportResult(
        totalRecipes: recipesJson.length,
        successCount: successCount,
        skipCount: skipCount,
        exportDate: DateTime.parse(backupData['exported_at']),
        exportEmail: backupData['user_email'],
        errors: errors,
        skippedTitles: skippedTitles,
      );
    } catch (e) {
      AppLogger.error('Import misslyckades', e);
      return ImportResult.error('Import misslyckades: $e');
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'januari',
      'februari',
      'mars',
      'april',
      'maj',
      'juni',
      'juli',
      'augusti',
      'september',
      'oktober',
      'november',
      'december',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class BackupResult {
  final bool success;
  final String message;
  final String? filePath;
  final int? recipeCount;

  const BackupResult({
    required this.success,
    required this.message,
    this.filePath,
    this.recipeCount,
  });

  factory BackupResult.success({
    required String message,
    required String filePath,
    required int recipeCount,
  }) {
    return BackupResult(
      success: true,
      message: message,
      filePath: filePath,
      recipeCount: recipeCount,
    );
  }

  factory BackupResult.error(String message) {
    return BackupResult(success: false, message: message);
  }
}

class ImportResult {
  final bool success;
  final bool cancelled;
  final int totalRecipes;
  final int successCount;
  final int skipCount;
  final DateTime? exportDate;
  final String? exportEmail;
  final List<String> errors;
  final List<String> skippedTitles;
  final String? errorMessage;

  const ImportResult({
    this.success = true,
    this.cancelled = false,
    this.totalRecipes = 0,
    this.successCount = 0,
    this.skipCount = 0,
    this.exportDate,
    this.exportEmail,
    this.errors = const [],
    this.skippedTitles = const [],
    this.errorMessage,
  });

  factory ImportResult.cancelled() {
    return const ImportResult(cancelled: true, success: false);
  }

  factory ImportResult.error(String message) {
    return ImportResult(success: false, errorMessage: message);
  }
}
