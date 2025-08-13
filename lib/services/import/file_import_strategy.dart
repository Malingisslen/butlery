import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/core/utils/logger.dart';

/// File import strategy for CSV and Excel files
/// Supports importing recipes from structured spreadsheet formats
class FileImportStrategy extends ImportStrategy {
  @override
  String get strategyName => 'File Import (CSV/Excel)';
  
  // @override removed - not in parent class
  String get name => 'File Import (CSV/Excel)';
  
  @override
  String get description => 'Import recipes from CSV or Excel files';
  
  @override
  String get inputExample => 'CSV or Excel file with columns: title, ingredients, instructions';
  
  @override
  bool validateInput(String input) {
    // File imports are handled through file picker, not text validation
    return false;
  }
  
  @override
  bool canHandle(String input) {
    // This strategy handles file picker operations, not direct text input
    return false;
  }
  
  // @override removed - not in parent class
  double calculateConfidence(String input) {
    // File imports are handled through file picker, not text analysis
    return 0.0;
  }
  
  @override
  Future<ImportResult> import(String input, {Map<String, dynamic>? options}) async {
    // This method expects a file path or uses file picker
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
        withData: true,
      );
      
      if (result == null || result.files.isEmpty) {
        return ImportResult.failure('No file selected');
      }
      
      final file = result.files.first;
      if (file.bytes == null) {
        return ImportResult.failure('Could not read file');
      }
      
      final extension = file.extension?.toLowerCase();
      
      Recipe? recipe;
      if (extension == 'csv') {
        recipe = await _importFromCsv(file.bytes!);
      } else if (extension == 'xlsx' || extension == 'xls') {
        recipe = await _importFromExcel(file.bytes!);
      } else {
        return ImportResult.failure('Unsupported file format: $extension');
      }
      
      if (recipe != null) {
        return ImportResult.success(recipe);
      } else {
        return ImportResult.failure('Failed to parse file');
      }
    } catch (e) {
      AppLogger.error('File import failed', e);
      return ImportResult.failure('Import failed: ${e.toString()}');
    }
  }
  
  /// Import multiple recipes from file
  Future<List<Recipe>> importMultiple({Map<String, dynamic>? options}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
        withData: true,
      );
      
      if (result == null || result.files.isEmpty) {
        return [];
      }
      
      final file = result.files.first;
      if (file.bytes == null) {
        throw Exception('Could not read file');
      }
      
      final extension = file.extension?.toLowerCase();
      
      if (extension == 'csv') {
        return await _importMultipleFromCsv(file.bytes!);
      } else if (extension == 'xlsx' || extension == 'xls') {
        return await _importMultipleFromExcel(file.bytes!);
      }
      
      throw Exception('Unsupported file format: $extension');
    } catch (e) {
      AppLogger.error('File import failed', e);
      return [];
    }
  }
  
  Future<Recipe?> _importFromCsv(Uint8List bytes) async {
    try {
      final csvString = utf8.decode(bytes);
      final List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);
      
      if (rows.isEmpty) {
        throw Exception('CSV file is empty');
      }
      
      // Assuming first row is headers
      final headers = rows.first.map((e) => e.toString().toLowerCase()).toList();
      
      if (rows.length < 2) {
        throw Exception('CSV file has no data rows');
      }
      
      // Import first data row as single recipe
      return _parseRecipeFromRow(headers, rows[1]);
    } catch (e) {
      AppLogger.error('CSV parsing failed', e);
      return null;
    }
  }
  
  Future<List<Recipe>> _importMultipleFromCsv(Uint8List bytes) async {
    try {
      final csvString = utf8.decode(bytes);
      final List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);
      
      if (rows.isEmpty) {
        throw Exception('CSV file is empty');
      }
      
      final headers = rows.first.map((e) => e.toString().toLowerCase()).toList();
      final recipes = <Recipe>[];
      
      // Skip header row and process all data rows
      for (int i = 1; i < rows.length; i++) {
        final recipe = _parseRecipeFromRow(headers, rows[i]);
        if (recipe != null) {
          recipes.add(recipe);
        }
      }
      
      return recipes;
    } catch (e) {
      AppLogger.error('CSV parsing failed', e);
      return [];
    }
  }
  
  Future<Recipe?> _importFromExcel(Uint8List bytes) async {
    try {
      final excel = Excel.decodeBytes(bytes);
      
      // Get first sheet
      final sheet = excel.tables.values.firstOrNull;
      if (sheet == null || sheet.rows.isEmpty) {
        throw Exception('Excel file is empty');
      }
      
      // Get headers from first row
      final headerRow = sheet.rows.first;
      final headers = headerRow.map((cell) => 
        cell?.value?.toString().toLowerCase() ?? '').toList();
      
      if (sheet.rows.length < 2) {
        throw Exception('Excel file has no data rows');
      }
      
      // Import first data row
      final dataRow = sheet.rows[1];
      return _parseRecipeFromExcelRow(headers, dataRow);
    } catch (e) {
      AppLogger.error('Excel parsing failed', e);
      return null;
    }
  }
  
  Future<List<Recipe>> _importMultipleFromExcel(Uint8List bytes) async {
    try {
      final excel = Excel.decodeBytes(bytes);
      
      final sheet = excel.tables.values.firstOrNull;
      if (sheet == null || sheet.rows.isEmpty) {
        throw Exception('Excel file is empty');
      }
      
      final headerRow = sheet.rows.first;
      final headers = headerRow.map((cell) => 
        cell?.value?.toString().toLowerCase() ?? '').toList();
      
      final recipes = <Recipe>[];
      
      // Skip header row and process all data rows
      for (int i = 1; i < sheet.rows.length; i++) {
        final recipe = _parseRecipeFromExcelRow(headers, sheet.rows[i]);
        if (recipe != null) {
          recipes.add(recipe);
        }
      }
      
      return recipes;
    } catch (e) {
      AppLogger.error('Excel parsing failed', e);
      return [];
    }
  }
  
  Recipe? _parseRecipeFromRow(List<String> headers, List<dynamic> row) {
    try {
      final Map<String, String> data = {};
      
      for (int i = 0; i < headers.length && i < row.length; i++) {
        data[headers[i]] = row[i]?.toString() ?? '';
      }
      
      return _createRecipeFromData(data);
    } catch (e) {
      AppLogger.error('Failed to parse recipe from row', e);
      return null;
    }
  }
  
  Recipe? _parseRecipeFromExcelRow(List<String> headers, List<Data?> row) {
    try {
      final Map<String, String> data = {};
      
      for (int i = 0; i < headers.length && i < row.length; i++) {
        data[headers[i]] = row[i]?.value?.toString() ?? '';
      }
      
      return _createRecipeFromData(data);
    } catch (e) {
      AppLogger.error('Failed to parse recipe from Excel row', e);
      return null;
    }
  }
  
  Recipe? _createRecipeFromData(Map<String, String> data) {
    // Map common column names to recipe fields
    final title = data['title'] ?? 
                  data['namn'] ?? 
                  data['recipe'] ?? 
                  data['recept'] ?? 
                  'Imported Recipe';
    
    if (title.isEmpty) {
      return null;
    }
    
    final ingredients = _parseIngredients(data);
    final instructions = _parseInstructions(data);
    
    return Recipe(
      core: RecipeCore(
        id: const Uuid().v4(),
        title: title,
        description: data['description'] ?? data['beskrivning'] ?? '',
        ingredients: ingredients,
        instructions: instructions,
        mealType: data['mealtype'] ?? data['måltidstyp'] ?? 'Middag',
        portions: _parseServings(data),
        timeMinutes: _parseCookingTime(data),
        tags: _parseTags(data),
        rating: _parseRating(data),
        sourceUrl: data['source'] ?? data['källa'] ?? 'file_import',
        imageUrls: _parseImageUrls(data),
        createdBy: null,
        isPublic: false,
      ),
      type: RecipeType.personal,
    );
  }
  
  List<String> _parseIngredients(Map<String, String> data) {
    // Check for ingredients column
    final ingredientsStr = data['ingredients'] ?? 
                           data['ingredienser'] ?? 
                           data['ingredient'] ?? '';
    
    if (ingredientsStr.isNotEmpty) {
      // Split by common delimiters
      return ingredientsStr
          .split(RegExp(r'[;\n|]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    
    // Check for numbered ingredient columns
    final ingredients = <String>[];
    for (int i = 1; i <= 50; i++) {
      final ingredient = data['ingredient$i'] ?? 
                         data['ingrediens$i'] ?? 
                         data['ingredient_$i'] ?? '';
      if (ingredient.isNotEmpty) {
        ingredients.add(ingredient);
      }
    }
    
    return ingredients;
  }
  
  List<String> _parseInstructions(Map<String, String> data) {
    final instructionsStr = data['instructions'] ?? 
                            data['instruktioner'] ?? 
                            data['steps'] ?? 
                            data['steg'] ?? '';
    
    if (instructionsStr.isNotEmpty) {
      return instructionsStr
          .split(RegExp(r'[;\n|]|(?:\d+\.)'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    
    // Check for numbered step columns
    final steps = <String>[];
    for (int i = 1; i <= 20; i++) {
      final step = data['step$i'] ?? 
                   data['steg$i'] ?? 
                   data['instruction$i'] ?? '';
      if (step.isNotEmpty) {
        steps.add(step);
      }
    }
    
    return steps;
  }
  
  int _parseCookingTime(Map<String, String> data) {
    final timeStr = data['cookingtime'] ?? 
                    data['cooking_time'] ?? 
                    data['tid'] ?? 
                    data['tillagingstid'] ?? 
                    data['time'] ?? 
                    '30';
    
    // Extract number from string
    final match = RegExp(r'\d+').firstMatch(timeStr);
    return match != null ? int.tryParse(match.group(0)!) ?? 30 : 30;
  }
  
  int _parseServings(Map<String, String> data) {
    final servingsStr = data['servings'] ?? 
                        data['portions'] ?? 
                        data['portioner'] ?? 
                        data['serves'] ?? 
                        '4';
    
    final match = RegExp(r'\d+').firstMatch(servingsStr);
    return match != null ? int.tryParse(match.group(0)!) ?? 4 : 4;
  }
  
  List<String> _parseTags(Map<String, String> data) {
    final tagsStr = data['tags'] ?? 
                    data['taggar'] ?? 
                    data['keywords'] ?? '';
    
    if (tagsStr.isNotEmpty) {
      return tagsStr
          .split(RegExp(r'[,;|]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    
    return [];
  }
  
  double? _parseRating(Map<String, String> data) {
    final ratingStr = data['rating'] ?? data['betyg'] ?? data['score'];
    if (ratingStr == null) return null;
    return double.tryParse(ratingStr);
  }
  
  List<String> _parseImageUrls(Map<String, String> data) {
    final imageUrl = data['image'] ?? data['bild'] ?? data['imageurl'];
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return [imageUrl];
    }
    return [];
  }
}