/// Comprehensive backup and restore service for recipe data management with cross-platform file operations.
///
/// This service provides sophisticated backup and restore functionality for recipe collections,
/// implementing platform-specific file storage strategies and comprehensive data integrity validation.
/// It enables users to export their recipe collections to JSON format and import recipes from
/// backup files with duplicate detection, error handling, and detailed operation reporting.
///
/// **Architecture Integration:**
/// - Integrates with [UnifiedRecipeService] for comprehensive recipe collection management
/// - Uses [FirebaseAuthRepository] for user authentication and ownership tracking
/// - Implements platform-specific file storage strategies for Android and iOS compatibility
/// - Coordinates with core dependency injection system for service orchestration
///
/// **Backup and Export Features:**
/// - **Cross-Platform Export**: Platform-specific file storage strategies for Android and iOS
/// - **JSON Formatting**: Human-readable JSON export with comprehensive metadata
/// - **Timestamped Files**: Automatic filename generation with export timestamps
/// - **User Attribution**: Export metadata includes user email and authentication information
/// - **Recipe Count Tracking**: Detailed statistics and recipe collection metadata
/// - **Error Recovery**: Comprehensive error handling with detailed failure reporting
///
/// **Import and Restore Features:**
/// - **File Format Validation**: Robust validation of backup file format and structure
/// - **Duplicate Detection**: Intelligent duplicate recipe detection based on title matching
/// - **Batch Processing**: Efficient batch import with detailed progress and error reporting
/// - **Legacy Compatibility**: Support for both current and legacy backup file formats
/// - **Data Integrity**: Comprehensive validation and error handling during import operations
/// - **User Feedback**: Detailed import results with success counts, skipped items, and error details
///
/// **Platform-Specific Storage:**
/// - **Android**: Intelligent Downloads folder management with fallback strategies
/// - **iOS**: Documents directory integration with Files app accessibility
/// - **File Organization**: Dedicated Butlery subdirectory creation for organized storage

import 'dart:convert';
import 'dart:io';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';

/// Backup and restore service providing comprehensive recipe data management with cross-platform file operations.
///
/// This service manages complete backup and restore workflows for recipe collections, implementing
/// sophisticated platform-specific file storage strategies and comprehensive data validation.
/// It provides both export and import functionality with detailed error handling, duplicate detection,
/// and user-friendly progress reporting throughout all operations.
///
/// **Cross-Platform Architecture:**
/// Implements platform-specific strategies for optimal file storage:
/// - Android: Downloads folder access with app-specific storage fallbacks
/// - iOS: Documents directory integration with Files app accessibility
/// - Comprehensive error handling for platform-specific storage limitations
///
/// **Data Integrity and Validation:**
/// Provides robust data handling including:
/// - JSON format validation with backward compatibility
/// - Duplicate recipe detection during import operations
/// - Comprehensive error reporting with detailed failure analysis
/// - Metadata preservation including export timestamps and user attribution
///
/// **Usage Examples:**
/// ```dart
/// final backupService = BackupService();
/// 
/// // Export all recipes to platform-specific location
/// final exportResult = await backupService.exportToFile();
/// if (exportResult.success) {
///   print('Exported ${exportResult.recipeCount} recipes to ${exportResult.filePath}');
/// }
/// 
/// // Import recipes from backup file
/// final importResult = await backupService.importFromFile();
/// if (importResult.success) {
///   print('Imported ${importResult.successCount} recipes, skipped ${importResult.skipCount}');
/// }
/// ```
class BackupService {
  /// Exports all recipes to a timestamped JSON file in platform-specific storage location.
  ///
  /// This method performs a comprehensive export of all available recipes to a JSON backup file,
  /// implementing platform-specific storage strategies to ensure optimal file accessibility.
  /// The export includes detailed metadata, timestamps, and user attribution for complete backup integrity.
  ///
  /// Returns [BackupResult] with detailed information about the export operation including:
  /// - Success/failure status with descriptive error messages
  /// - File path location for user reference and verification
  /// - Recipe count statistics for export validation
  /// - Platform-specific storage location details
  ///
  /// **Export Process:**
  /// 1. Retrieves all recipes from UnifiedRecipeService
  /// 2. Creates comprehensive JSON structure with metadata
  /// 3. Generates timestamped filename for organization
  /// 4. Implements platform-specific storage strategy (Android/iOS)
  /// 5. Provides detailed success/failure reporting
  ///
  /// **Platform Storage Strategies:**
  /// - **Android**: Downloads folder with Butlery subdirectory
  /// - **iOS**: Documents directory accessible through Files app
  /// - **Error Handling**: Comprehensive fallback strategies and error reporting
  ///
  /// **JSON Structure:**
  /// The exported JSON includes:
  /// - Backup version and timestamp metadata
  /// - User email and authentication information
  /// - Recipe count statistics and validation data
  /// - Complete recipe collection with all properties preserved
  Future<BackupResult> exportToFile() async {
    try {
      // Hämta alla recept
      final recipeService = ServiceLocator.get<UnifiedRecipeService>();
      final recipes = recipeService.recipes;

      if (recipes.isEmpty) {
        return BackupResult.error('Inga recept att exportera');
      }

      // Skapa JSON-struktur
      final jsonData = {
        'butlery_backup': {
          'version': '1.0',
          'exported_at': DateTime.now().toIso8601String(),
          'user_email': FirebaseAuthRepository().currentUser?.email,
          'recipe_count': recipes.length,
          'recipes': recipes.map((r) => r.toJson()).toList(),
        },
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);

      // Skapa filnamn med timestamp
      final timestamp = DateTime.now();
      final filename =
          'butlery_backup_${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}_${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}.json';

      // Olika strategier för olika plattformar
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

  /// Spara till Android Downloads-mappen
  Future<BackupResult> _saveToAndroidDownloads(
    String content,
    String filename,
    int recipeCount,
  ) async {
    try {
      // Android 10+ (API 29+) behöver inte storage permission för app-specifika mappar
      // Vi använder app-specifik extern lagring som användaren kan komma åt
      Directory? directory;

      // Hämta Downloads-mappen direkt
      try {
        // Detta ger oss path till Downloads
        final List<Directory>? dirs = await getExternalStorageDirectories(
          type: StorageDirectory.downloads,
        );
        if (dirs != null && dirs.isNotEmpty) {
          // Ta bort Android-specifika delar från path för att få riktig Downloads-mapp
          String path = dirs.first.path;
          // Byt ut allt efter "Android" med "Download"
          final androidIndex = path.indexOf('/Android');
          if (androidIndex != -1) {
            path = '${path.substring(0, androidIndex)}/Download';
          }
          directory = Directory(path);
        }
      } catch (e) {
        // Fallback till app-specifik mapp
        directory = await getExternalStorageDirectory();
      }
      if (directory == null) {
        return BackupResult.error('Kunde inte hitta lagringsmapp');
      }

      // Skapa Butlery-mapp
      final butleryDir = Directory('${directory.path}/Butlery');
      if (!await butleryDir.exists()) {
        await butleryDir.create(recursive: true);
      }

      // Spara filen
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

  /// Spara till iOS Documents-mappen
  Future<BackupResult> _saveToIOSDocuments(
    String content,
    String filename,
    int recipeCount,
  ) async {
    try {
      // iOS behöver inga särskilda permissions för app documents
      final directory = await getApplicationDocumentsDirectory();

      // Skapa Butlery-mapp
      final butleryDir = Directory('${directory.path}/Butlery');
      if (!await butleryDir.exists()) {
        await butleryDir.create(recursive: true);
      }

      // Spara filen
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

  /// Imports recipes from a user-selected backup file with comprehensive validation and duplicate detection.
  ///
  /// This method provides a complete import workflow allowing users to restore recipes from backup files.
  /// It implements sophisticated validation, duplicate detection, and detailed progress reporting to ensure
  /// data integrity and provide comprehensive feedback about the import operation results.
  ///
  /// Returns [ImportResult] with detailed information about the import operation including:
  /// - Success/failure status with comprehensive error reporting
  /// - Total recipe count from backup file for validation
  /// - Successfully imported recipe count with detailed statistics
  /// - Skipped recipe count with duplicate detection results
  /// - Export metadata including original export date and user information
  /// - Detailed error list with specific failure reasons for troubleshooting
  ///
  /// **Import Process:**
  /// 1. Opens file picker for user to select backup JSON file
  /// 2. Validates backup file format and structure integrity
  /// 3. Processes each recipe with duplicate detection (title-based matching)
  /// 4. Creates new recipe entries with updated timestamps and IDs
  /// 5. Provides comprehensive success/failure reporting with detailed statistics
  ///
  /// **Validation and Error Handling:**
  /// - **Format Validation**: Ensures backup file is valid Butlery format
  /// - **Duplicate Detection**: Prevents duplicate imports based on recipe titles
  /// - **Legacy Compatibility**: Supports both current and legacy backup formats
  /// - **Error Recovery**: Continues processing even if individual recipes fail
  /// - **Detailed Reporting**: Provides specific error messages for troubleshooting
  ///
  /// **Data Processing:**
  /// - Preserves original recipe data while updating system-specific fields
  /// - Generates new unique IDs for imported recipes
  /// - Updates timestamps to reflect import date
  /// - Maintains source attribution with backup import metadata
  Future<ImportResult> importFromFile() async {
    try {
      // Låt användaren välja fil
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

      // Parse JSON
      final jsonString = utf8.decode(file.bytes!);
      final jsonData = json.decode(jsonString);

      // Validera format
      if (!jsonData.containsKey('butlery_backup') &&
          !jsonData.containsKey('butlery_export')) {
        return ImportResult.error('Ogiltig backup-fil - inte från Butlery');
      }

      // Hantera både gamla export-format och nya backup-format
      final backupData =
          jsonData['butlery_backup'] ?? jsonData['butlery_export'];
      final recipesJson = backupData['recipes'] as List;

      // Importera recept
      final recipeService = ServiceLocator.get<UnifiedRecipeService>();
      int successCount = 0;
      int skipCount = 0;
      final errors = <String>[];
      final skippedTitles = <String>[];

      for (final recipeJson in recipesJson) {
        try {
          final recipe = Recipe.fromJson(recipeJson);

          // Kolla om receptet redan finns (baserat på titel)
          final existingRecipes = recipeService.recipes;
          final alreadyExists = existingRecipes.any(
            (r) => r.title.toLowerCase() == recipe.title.toLowerCase(),
          );

          if (alreadyExists) {
            skipCount++;
            skippedTitles.add(recipe.title);
            continue;
          }

          // Skapa nytt recept med ny ID
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
              tags: recipe.tags,
              sourceUrl: 'Importerat från backup ${_formatDate(DateTime.now())}',
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
            tags: newRecipe.tags,
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

  /// Formatera datum för visning
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

/// Comprehensive result data for backup export operations with detailed success/failure information.
///
/// This class encapsulates all relevant information from a backup export operation, providing
/// detailed feedback for user interfaces and logging systems. It includes success status,
/// descriptive messages, file system information, and statistical data about the export process.
///
/// **Key Properties:**
/// - [success] Boolean indicating whether the backup operation completed successfully
/// - [message] User-friendly message describing the operation result or error details
/// - [filePath] Complete file system path where the backup was saved (null on failure)
/// - [recipeCount] Number of recipes included in the backup (null on failure)
///
/// **Usage Patterns:**
/// - Success results include file path and recipe count for user confirmation
/// - Error results provide detailed error messages for troubleshooting
/// - Factory constructors ensure consistent result formatting across all operations
class BackupResult {
  /// Whether the backup operation completed successfully.
  final bool success;
  
  /// User-friendly message describing the operation result or error details.
  final String message;
  
  /// Complete file system path where the backup was saved (null on failure).
  final String? filePath;
  
  /// Number of recipes included in the backup (null on failure).
  final int? recipeCount;

  /// Creates a BackupResult with comprehensive operation details.
  ///
  /// [success] Whether the backup operation completed successfully
  /// [message] User-friendly message describing the operation result
  /// [filePath] Optional file path where backup was saved (for successful operations)
  /// [recipeCount] Optional count of recipes in backup (for successful operations)
  const BackupResult({
    required this.success,
    required this.message,
    this.filePath,
    this.recipeCount,
  });

  /// Factory constructor for successful backup operations with comprehensive result data.
  ///
  /// Creates a BackupResult indicating successful completion with detailed operation information
  /// including file location and recipe statistics for user confirmation and verification.
  ///
  /// [message] Success message describing the completed operation
  /// [filePath] Complete file system path where the backup was saved
  /// [recipeCount] Number of recipes successfully included in the backup
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

  /// Factory constructor for failed backup operations with detailed error information.
  ///
  /// Creates a BackupResult indicating operation failure with comprehensive error details
  /// for troubleshooting and user feedback. Includes null values for optional properties
  /// to clearly indicate the operation did not complete successfully.
  ///
  /// [message] Error message describing what went wrong during the backup operation
  factory BackupResult.error(String message) {
    return BackupResult(success: false, message: message);
  }
}

/// Comprehensive result data for backup import operations with detailed statistics and error reporting.
///
/// This class provides comprehensive feedback about import operations, including detailed statistics
/// about successful imports, skipped duplicates, errors encountered, and metadata from the original
/// backup file. It enables sophisticated user feedback and troubleshooting capabilities.
///
/// **Statistical Properties:**
/// - [totalRecipes] Total number of recipes found in the backup file
/// - [successCount] Number of recipes successfully imported into the system
/// - [skipCount] Number of recipes skipped due to duplicates or errors
/// - [errors] Detailed list of error messages for troubleshooting
/// - [skippedTitles] List of recipe titles that were skipped during import
///
/// **Operation Status:**
/// - [success] Whether the overall import operation completed successfully
/// - [cancelled] Whether the user cancelled the file selection process
/// - [errorMessage] General error message if the entire operation failed
///
/// **Backup Metadata:**
/// - [exportDate] Original export date from the backup file metadata
/// - [exportEmail] Email of the user who created the original backup
class ImportResult {
  /// Whether the overall import operation completed successfully.
  final bool success;
  
  /// Whether the user cancelled the file selection process.
  final bool cancelled;
  
  /// Total number of recipes found in the backup file.
  final int totalRecipes;
  
  /// Number of recipes successfully imported into the system.
  final int successCount;
  
  /// Number of recipes skipped due to duplicates or errors.
  final int skipCount;
  
  /// Original export date from the backup file metadata.
  final DateTime? exportDate;
  
  /// Email of the user who created the original backup.
  final String? exportEmail;
  
  /// Detailed list of error messages for troubleshooting.
  final List<String> errors;
  
  /// List of recipe titles that were skipped during import.
  final List<String> skippedTitles;
  
  /// General error message if the entire operation failed.
  final String? errorMessage;

  /// Creates an ImportResult with comprehensive import operation details.
  ///
  /// [success] Whether the overall import operation completed successfully (defaults to true)
  /// [cancelled] Whether the user cancelled the file selection process (defaults to false)
  /// [totalRecipes] Total number of recipes found in the backup file (defaults to 0)
  /// [successCount] Number of recipes successfully imported (defaults to 0)
  /// [skipCount] Number of recipes skipped due to duplicates or errors (defaults to 0)
  /// [exportDate] Original export date from backup file metadata
  /// [exportEmail] Email of user who created the original backup
  /// [errors] Detailed list of error messages for troubleshooting (defaults to empty)
  /// [skippedTitles] List of recipe titles that were skipped (defaults to empty)
  /// [errorMessage] General error message if the entire operation failed
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

  /// Factory constructor for cancelled import operations.
  ///
  /// Creates an ImportResult indicating that the user cancelled the file selection
  /// process before any import operations could begin. This provides clear distinction
  /// between user cancellation and actual import failures.
  factory ImportResult.cancelled() {
    return const ImportResult(cancelled: true, success: false);
  }

  /// Factory constructor for failed import operations with detailed error information.
  ///
  /// Creates an ImportResult indicating operation failure with comprehensive error details
  /// for troubleshooting and user feedback. Used when the entire import process fails
  /// due to file format issues, system errors, or other critical problems.
  ///
  /// [message] Error message describing what went wrong during the import operation
  factory ImportResult.error(String message) {
    return ImportResult(success: false, errorMessage: message);
  }
}
