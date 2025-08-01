#!/usr/bin/env dart
// 🏭 BULK GENERATOR - Ultra Code Generation Tool
// Generates boilerplate code in bulk with intelligent templates
// Usage: dart bulk_generator.dart [template_type] [options]

import 'dart:io';
import 'dart:convert';

void main(List<String> args) async {
  if (args.isEmpty) {
    _printUsage();
    exit(1);
  }

  final templateType = args[0];
  final options = _parseOptions(args.skip(1).toList());

  print('🏭 BULK GENERATOR - Ultra Code Generation');
  print('Template Type: $templateType');
  print('Options: ${options.toString()}');
  print('');

  final stopwatch = Stopwatch()..start();

  // Get generator for the specified template type
  final generator = _getGenerator(templateType);
  if (generator == null) {
    print('❌ Unknown template type: $templateType');
    _printAvailableTemplates();
    exit(1);
  }

  // Execute bulk generation
  final result = await generator.generate(options);

  stopwatch.stop();

  print('\n🏭 BULK GENERATION COMPLETE!');
  print('⏱️  Time: ${stopwatch.elapsed.inMilliseconds}ms');
  print('📁 Files generated: ${result.filesGenerated}');
  print('📝 Lines of code: ${result.linesGenerated}');
  print('🎯 Templates applied: ${result.templatesApplied}');
  
  if (result.errors.isNotEmpty) {
    print('\n⚠️  Errors encountered:');
    for (final error in result.errors) {
      print('  - $error');
    }
  }

  if (result.generatedFiles.isNotEmpty) {
    print('\n📋 Generated files:');
    for (final file in result.generatedFiles) {
      print('  ✅ $file');
    }
  }
}

void _printUsage() {
  print('''
🏭 BULK GENERATOR - Ultra Code Generation Tool

USAGE:
  dart bulk_generator.dart [template_type] [options]

TEMPLATE TYPES:
  models           - Generate model classes with JSON serialization
  repositories     - Generate repository pattern implementations  
  services         - Generate service layer classes
  viewmodels       - Generate MVVM ViewModel classes
  widgets          - Generate reusable widget components
  tests            - Generate comprehensive test suites
  facades          - Generate facade pattern implementations
  validators       - Generate validation classes
  extensions       - Generate extension method classes
  mixins           - Generate reusable mixin classes
  interfaces       - Generate interface/abstract classes
  all              - Generate complete feature set (nuclear option)

OPTIONS:
  --entities=LIST    Comma-separated list of entity names (e.g., Recipe,User,Menu)
  --output=DIR       Output directory (default: lib/generated)
  --template=FILE    Custom template file to use
  --dry-run          Show what would be generated without creating files
  --overwrite        Overwrite existing files
  --naming=STYLE     Naming convention (snake_case, camelCase, PascalCase)
  --features=LIST    Additional features to include (validation,json,equatable)

EXAMPLES:
  # Generate models for Recipe, User, Menu entities
  dart bulk_generator.dart models --entities=Recipe,User,Menu

  # Generate complete repository layer
  dart bulk_generator.dart repositories --entities=Recipe,User --features=validation

  # Generate test suites for all services
  dart bulk_generator.dart tests --entities=Recipe,User,Menu --output=test/

  # Nuclear option: Generate everything for a feature
  dart bulk_generator.dart all --entities=Recipe --features=json,validation,tests
''');
}

void _printAvailableTemplates() {
  print('\nAvailable Template Types:');
  final templates = {
    'models': 'Data model classes with JSON serialization',
    'repositories': 'Repository pattern implementations',
    'services': 'Service layer classes',
    'viewmodels': 'MVVM ViewModel classes',
    'widgets': 'Reusable widget components',
    'tests': 'Comprehensive test suites',
    'facades': 'Facade pattern implementations',
    'validators': 'Validation classes',
    'extensions': 'Extension method classes',
    'mixins': 'Reusable mixin classes',
    'interfaces': 'Interface/abstract classes',
    'all': 'Complete feature set (nuclear)',
  };

  for (final entry in templates.entries) {
    print('  ${entry.key.padRight(15)} - ${entry.value}');
  }
}

GenerationOptions _parseOptions(List<String> args) {
  final options = GenerationOptions();
  
  for (final arg in args) {
    if (arg.startsWith('--entities=')) {
      options.entities = arg.substring(11).split(',').map((e) => e.trim()).toList();
    } else if (arg.startsWith('--output=')) {
      options.outputDir = arg.substring(9);
    } else if (arg.startsWith('--template=')) {
      options.templateFile = arg.substring(11);
    } else if (arg.startsWith('--naming=')) {
      options.namingStyle = arg.substring(9);
    } else if (arg.startsWith('--features=')) {
      options.features = arg.substring(11).split(',').map((e) => e.trim()).toList();
    } else {
      switch (arg) {
        case '--dry-run':
          options.dryRun = true;
          break;
        case '--overwrite':
          options.overwrite = true;
          break;
        default:
          print('⚠️  Unknown option: $arg');
      }
    }
  }
  
  return options;
}

BulkGenerator? _getGenerator(String templateType) {
  switch (templateType.toLowerCase()) {
    case 'models':
      return ModelGenerator();
    case 'repositories':
      return RepositoryGenerator();
    case 'services':
      return ServiceGenerator();
    case 'viewmodels':
      return ViewModelGenerator();
    case 'widgets':
      return WidgetGenerator();
    case 'tests':
      return TestGenerator();
    case 'facades':
      return FacadeGenerator();
    case 'validators':
      return ValidatorGenerator();
    case 'extensions':
      return ExtensionGenerator();
    case 'mixins':
      return MixinGenerator();
    case 'interfaces':
      return InterfaceGenerator();
    case 'all':
      return AllGenerator();
    default:
      return null;
  }
}

// Base generator class
abstract class BulkGenerator {
  String get templateName;
  String get description;
  
  Future<GenerationResult> generate(GenerationOptions options);
  
  String toPascalCase(String input) {
    return input.split('_')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join('');
  }
  
  String toCamelCase(String input) {
    final pascalCase = toPascalCase(input);
    return pascalCase.isEmpty ? '' : pascalCase[0].toLowerCase() + pascalCase.substring(1);
  }
  
  String toSnakeCase(String input) {
    return input.replaceAllMapped(RegExp(r'([A-Z])'), (match) => '_${match.group(1)!.toLowerCase()}')
        .replaceFirst(RegExp(r'^_'), '');
  }
  
  Future<void> ensureDirectoryExists(String path) async {
    final directory = Directory(path);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }
}

// Model Generator
class ModelGenerator extends BulkGenerator {
  @override
  String get templateName => 'Model Classes';
  
  @override
  String get description => 'Generates data model classes with JSON serialization';
  
  @override
  Future<GenerationResult> generate(GenerationOptions options) async {
    print('🎯 Generating model classes...');
    
    final result = GenerationResult();
    
    if (options.entities.isEmpty) {
      result.errors.add('No entities specified. Use --entities=Entity1,Entity2');
      return result;
    }
    
    await ensureDirectoryExists('${options.outputDir}/models');
    
    for (final entity in options.entities) {
      try {
        final content = _generateModelContent(entity, options);
        final fileName = '${toSnakeCase(entity)}.dart';
        final filePath = '${options.outputDir}/models/$fileName';
        
        if (options.dryRun) {
          print('DRY RUN: Would generate $filePath');
          result.filesGenerated++;
          continue;
        }
        
        final file = File(filePath);
        if (await file.exists() && !options.overwrite) {
          print('⚠️  Skipping existing file: $filePath');
          continue;
        }
        
        await file.writeAsString(content);
        result.filesGenerated++;
        result.linesGenerated += content.split('\n').length;
        result.generatedFiles.add(filePath);
        result.templatesApplied++;
        
        print('✅ Generated model: $filePath');
        
      } catch (e) {
        result.errors.add('Error generating model for $entity: $e');
      }
    }
    
    return result;
  }
  
  String _generateModelContent(String entity, GenerationOptions options) {
    final className = toPascalCase(entity);
    final hasJson = options.features.contains('json');
    final hasEquatable = options.features.contains('equatable');
    final hasValidation = options.features.contains('validation');
    
    final buffer = StringBuffer();
    
    // Imports
    buffer.writeln("import 'package:flutter/foundation.dart';");
    if (hasJson) {
      buffer.writeln("import 'dart:convert';");
    }
    if (hasEquatable) {
      buffer.writeln("import 'package:equatable/equatable.dart';");
    }
    buffer.writeln();
    
    // Class documentation
    buffer.writeln('/// $className data model');
    buffer.writeln('/// Generated by Bulk Generator');
    buffer.writeln('/// Features: ${options.features.join(', ')}');
    
    // Class declaration
    if (hasEquatable) {
      buffer.writeln('class $className extends Equatable {');
    } else {
      buffer.writeln('class $className {');
    }
    
    // Properties (example properties)
    buffer.writeln('  final String id;');
    buffer.writeln('  final String name;');
    buffer.writeln('  final DateTime createdAt;');
    buffer.writeln('  final DateTime updatedAt;');
    buffer.writeln();
    
    // Constructor
    buffer.writeln('  const $className({');
    buffer.writeln('    required this.id,');
    buffer.writeln('    required this.name,');
    buffer.writeln('    required this.createdAt,');
    buffer.writeln('    required this.updatedAt,');
    buffer.writeln('  });');
    buffer.writeln();
    
    // JSON serialization
    if (hasJson) {
      buffer.writeln('  /// Create $className from JSON');
      buffer.writeln('  factory $className.fromJson(Map<String, dynamic> json) {');
      buffer.writeln('    return $className(');
      buffer.writeln("      id: json['id'] as String,");
      buffer.writeln("      name: json['name'] as String,");
      buffer.writeln("      createdAt: DateTime.parse(json['createdAt'] as String),");
      buffer.writeln("      updatedAt: DateTime.parse(json['updatedAt'] as String),");
      buffer.writeln('    );');
      buffer.writeln('  }');
      buffer.writeln();
      
      buffer.writeln('  /// Convert $className to JSON');
      buffer.writeln('  Map<String, dynamic> toJson() {');
      buffer.writeln('    return {');
      buffer.writeln("      'id': id,");
      buffer.writeln("      'name': name,");
      buffer.writeln("      'createdAt': createdAt.toIso8601String(),");
      buffer.writeln("      'updatedAt': updatedAt.toIso8601String(),");
      buffer.writeln('    };');
      buffer.writeln('  }');
      buffer.writeln();
    }
    
    // Copy with method
    buffer.writeln('  /// Create a copy of $className with updated fields');
    buffer.writeln('  $className copyWith({');
    buffer.writeln('    String? id,');
    buffer.writeln('    String? name,');
    buffer.writeln('    DateTime? createdAt,');
    buffer.writeln('    DateTime? updatedAt,');
    buffer.writeln('  }) {');
    buffer.writeln('    return $className(');
    buffer.writeln('      id: id ?? this.id,');
    buffer.writeln('      name: name ?? this.name,');
    buffer.writeln('      createdAt: createdAt ?? this.createdAt,');
    buffer.writeln('      updatedAt: updatedAt ?? this.updatedAt,');
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln();
    
    // Equatable
    if (hasEquatable) {
      buffer.writeln('  @override');
      buffer.writeln('  List<Object?> get props => [id, name, createdAt, updatedAt];');
      buffer.writeln();
    }
    
    // toString
    buffer.writeln('  @override');
    buffer.writeln('  String toString() {');
    buffer.writeln("    return '$className(id: \$id, name: \$name)';");
    buffer.writeln('  }');
    
    // Validation
    if (hasValidation) {
      buffer.writeln();
      buffer.writeln('  /// Validate $className data');
      buffer.writeln('  List<String> validate() {');
      buffer.writeln('    final errors = <String>[];');
      buffer.writeln('    ');
      buffer.writeln('    if (id.isEmpty) {');
      buffer.writeln("      errors.add('ID cannot be empty');");
      buffer.writeln('    }');
      buffer.writeln('    ');
      buffer.writeln('    if (name.isEmpty) {');
      buffer.writeln("      errors.add('Name cannot be empty');");
      buffer.writeln('    }');
      buffer.writeln('    ');
      buffer.writeln('    return errors;');
      buffer.writeln('  }');
      buffer.writeln();
      
      buffer.writeln('  /// Check if $className is valid');
      buffer.writeln('  bool get isValid => validate().isEmpty;');
    }
    
    buffer.writeln('}');
    
    return buffer.toString();
  }
}

// Repository Generator
class RepositoryGenerator extends BulkGenerator {
  @override
  String get templateName => 'Repository Classes';
  
  @override
  String get description => 'Generates repository pattern implementations';
  
  @override
  Future<GenerationResult> generate(GenerationOptions options) async {
    print('🗃️  Generating repository classes...');
    
    final result = GenerationResult();
    
    if (options.entities.isEmpty) {
      result.errors.add('No entities specified. Use --entities=Entity1,Entity2');
      return result;
    }
    
    await ensureDirectoryExists('${options.outputDir}/repositories');
    
    for (final entity in options.entities) {
      try {
        final content = _generateRepositoryContent(entity, options);
        final fileName = '${toSnakeCase(entity)}_repository.dart';
        final filePath = '${options.outputDir}/repositories/$fileName';
        
        if (options.dryRun) {
          print('DRY RUN: Would generate $filePath');
          result.filesGenerated++;
          continue;
        }
        
        final file = File(filePath);
        if (await file.exists() && !options.overwrite) {
          print('⚠️  Skipping existing file: $filePath');
          continue;
        }
        
        await file.writeAsString(content);
        result.filesGenerated++;
        result.linesGenerated += content.split('\n').length;
        result.generatedFiles.add(filePath);
        result.templatesApplied++;
        
        print('✅ Generated repository: $filePath');
        
      } catch (e) {
        result.errors.add('Error generating repository for $entity: $e');
      }
    }
    
    return result;
  }
  
  String _generateRepositoryContent(String entity, GenerationOptions options) {
    final className = toPascalCase(entity);
    final repositoryName = '${className}Repository';
    final interfaceName = 'I${className}Repository';
    
    final buffer = StringBuffer();
    
    // Imports
    buffer.writeln("import 'package:cloud_firestore/cloud_firestore.dart';");
    buffer.writeln("import '../models/${toSnakeCase(entity)}.dart';");
    buffer.writeln("import '../core/error/failures.dart';");
    buffer.writeln("import '../core/error/exceptions.dart';");
    buffer.writeln();
    
    // Interface
    buffer.writeln('/// Repository interface for $className operations');
    buffer.writeln('abstract class $interfaceName {');
    buffer.writeln('  Future<$className?> getById(String id);');
    buffer.writeln('  Future<List<$className>> getAll();');
    buffer.writeln('  Future<$className> create($className ${toCamelCase(entity)});');
    buffer.writeln('  Future<$className> update($className ${toCamelCase(entity)});');
    buffer.writeln('  Future<void> delete(String id);');
    buffer.writeln('  Stream<List<$className>> watchAll();');
    buffer.writeln('  Stream<$className?> watchById(String id);');
    buffer.writeln('}');
    buffer.writeln();
    
    // Implementation
    buffer.writeln('/// Firebase implementation of $className repository');
    buffer.writeln('class $repositoryName implements $interfaceName {');
    buffer.writeln('  final FirebaseFirestore _firestore;');
    buffer.writeln('  static const String _collection = \'${toSnakeCase(entity)}s\';');
    buffer.writeln();
    
    buffer.writeln('  $repositoryName({FirebaseFirestore? firestore})');
    buffer.writeln('      : _firestore = firestore ?? FirebaseFirestore.instance;');
    buffer.writeln();
    
    buffer.writeln('  CollectionReference get _collectionRef => _firestore.collection(_collection);');
    buffer.writeln();
    
    // Get by ID
    buffer.writeln('  @override');
    buffer.writeln('  Future<$className?> getById(String id) async {');
    buffer.writeln('    try {');
    buffer.writeln('      final doc = await _collectionRef.doc(id).get();');
    buffer.writeln('      ');
    buffer.writeln('      if (!doc.exists) return null;');
    buffer.writeln('      ');
    buffer.writeln('      return $className.fromJson({');
    buffer.writeln("        'id': doc.id,");
    buffer.writeln('        ...doc.data() as Map<String, dynamic>,');
    buffer.writeln('      });');
    buffer.writeln('    } catch (e) {');
    buffer.writeln('      throw ServerException(\'Failed to get $entity: \$e\');');
    buffer.writeln('    }');
    buffer.writeln('  }');
    buffer.writeln();
    
    // Get all
    buffer.writeln('  @override');
    buffer.writeln('  Future<List<$className>> getAll() async {');
    buffer.writeln('    try {');
    buffer.writeln('      final querySnapshot = await _collectionRef.get();');
    buffer.writeln('      ');
    buffer.writeln('      return querySnapshot.docs.map((doc) {');
    buffer.writeln('        return $className.fromJson({');
    buffer.writeln("          'id': doc.id,");
    buffer.writeln('          ...doc.data() as Map<String, dynamic>,');
    buffer.writeln('        });');
    buffer.writeln('      }).toList();');
    buffer.writeln('    } catch (e) {');
    buffer.writeln('      throw ServerException(\'Failed to get ${entity}s: \$e\');');
    buffer.writeln('    }');
    buffer.writeln('  }');
    buffer.writeln();
    
    // Create
    buffer.writeln('  @override');
    buffer.writeln('  Future<$className> create($className ${toCamelCase(entity)}) async {');
    buffer.writeln('    try {');
    buffer.writeln('      final docRef = await _collectionRef.add(${toCamelCase(entity)}.toJson());');
    buffer.writeln('      ');
    buffer.writeln('      return ${toCamelCase(entity)}.copyWith(id: docRef.id);');
    buffer.writeln('    } catch (e) {');
    buffer.writeln('      throw ServerException(\'Failed to create $entity: \$e\');');
    buffer.writeln('    }');
    buffer.writeln('  }');
    buffer.writeln();
    
    // Update
    buffer.writeln('  @override');
    buffer.writeln('  Future<$className> update($className ${toCamelCase(entity)}) async {');
    buffer.writeln('    try {');
    buffer.writeln('      await _collectionRef.doc(${toCamelCase(entity)}.id).update(${toCamelCase(entity)}.toJson());');
    buffer.writeln('      ');
    buffer.writeln('      return ${toCamelCase(entity)};');
    buffer.writeln('    } catch (e) {');
    buffer.writeln('      throw ServerException(\'Failed to update $entity: \$e\');');
    buffer.writeln('    }');
    buffer.writeln('  }');
    buffer.writeln();
    
    // Delete
    buffer.writeln('  @override');
    buffer.writeln('  Future<void> delete(String id) async {');
    buffer.writeln('    try {');
    buffer.writeln('      await _collectionRef.doc(id).delete();');
    buffer.writeln('    } catch (e) {');
    buffer.writeln('      throw ServerException(\'Failed to delete $entity: \$e\');');
    buffer.writeln('    }');
    buffer.writeln('  }');
    buffer.writeln();
    
    // Watch all
    buffer.writeln('  @override');
    buffer.writeln('  Stream<List<$className>> watchAll() {');
    buffer.writeln('    return _collectionRef.snapshots().map((snapshot) {');
    buffer.writeln('      return snapshot.docs.map((doc) {');
    buffer.writeln('        return $className.fromJson({');
    buffer.writeln("          'id': doc.id,");
    buffer.writeln('          ...doc.data() as Map<String, dynamic>,');
    buffer.writeln('        });');
    buffer.writeln('      }).toList();');
    buffer.writeln('    });');
    buffer.writeln('  }');
    buffer.writeln();
    
    // Watch by ID
    buffer.writeln('  @override');
    buffer.writeln('  Stream<$className?> watchById(String id) {');
    buffer.writeln('    return _collectionRef.doc(id).snapshots().map((doc) {');
    buffer.writeln('      if (!doc.exists) return null;');
    buffer.writeln('      ');
    buffer.writeln('      return $className.fromJson({');
    buffer.writeln("        'id': doc.id,");
    buffer.writeln('        ...doc.data() as Map<String, dynamic>,');
    buffer.writeln('      });');
    buffer.writeln('    });');
    buffer.writeln('  }');
    buffer.writeln('}');
    
    return buffer.toString();
  }
}

// Simplified implementations for other generators
class ServiceGenerator extends BulkGenerator {
  @override
  String get templateName => 'Service Classes';
  
  @override
  String get description => 'Generates service layer classes';
  
  @override
  Future<GenerationResult> generate(GenerationOptions options) async {
    return GenerationResult()..errors.add('Service generator not yet implemented');
  }
}

class ViewModelGenerator extends BulkGenerator {
  @override
  String get templateName => 'ViewModel Classes';
  
  @override
  String get description => 'Generates MVVM ViewModel classes';
  
  @override
  Future<GenerationResult> generate(GenerationOptions options) async {
    return GenerationResult()..errors.add('ViewModel generator not yet implemented');
  }
}

class WidgetGenerator extends BulkGenerator {
  @override
  String get templateName => 'Widget Components';
  
  @override
  String get description => 'Generates reusable widget components';
  
  @override
  Future<GenerationResult> generate(GenerationOptions options) async {
    return GenerationResult()..errors.add('Widget generator not yet implemented');
  }
}

class TestGenerator extends BulkGenerator {
  @override
  String get templateName => 'Test Suites';
  
  @override
  String get description => 'Generates comprehensive test suites';
  
  @override
  Future<GenerationResult> generate(GenerationOptions options) async {
    return GenerationResult()..errors.add('Test generator not yet implemented');
  }
}

class FacadeGenerator extends BulkGenerator {
  @override
  String get templateName => 'Facade Patterns';
  
  @override
  String get description => 'Generates facade pattern implementations';
  
  @override
  Future<GenerationResult> generate(GenerationOptions options) async {
    return GenerationResult()..errors.add('Facade generator not yet implemented');
  }
}

class ValidatorGenerator extends BulkGenerator {
  @override
  String get templateName => 'Validator Classes';
  
  @override
  String get description => 'Generates validation classes';
  
  @override
  Future<GenerationResult> generate(GenerationOptions options) async {
    return GenerationResult()..errors.add('Validator generator not yet implemented');
  }
}

class ExtensionGenerator extends BulkGenerator {
  @override
  String get templateName => 'Extension Methods';
  
  @override
  String get description => 'Generates extension method classes';
  
  @override
  Future<GenerationResult> generate(GenerationOptions options) async {
    return GenerationResult()..errors.add('Extension generator not yet implemented');
  }
}

class MixinGenerator extends BulkGenerator {
  @override
  String get templateName => 'Mixin Classes';
  
  @override
  String get description => 'Generates reusable mixin classes';
  
  @override
  Future<GenerationResult> generate(GenerationOptions options) async {
    return GenerationResult()..errors.add('Mixin generator not yet implemented');
  }
}

class InterfaceGenerator extends BulkGenerator {
  @override
  String get templateName => 'Interface Classes';
  
  @override
  String get description => 'Generates interface/abstract classes';
  
  @override
  Future<GenerationResult> generate(GenerationOptions options) async {
    return GenerationResult()..errors.add('Interface generator not yet implemented');
  }
}

class AllGenerator extends BulkGenerator {
  @override
  String get templateName => 'Complete Feature Set';
  
  @override
  String get description => 'Generates complete feature set (nuclear option)';
  
  @override
  Future<GenerationResult> generate(GenerationOptions options) async {
    print('🔥 NUCLEAR BULK GENERATION ACTIVATED');
    
    final combinedResult = GenerationResult();
    
    final generators = [
      ModelGenerator(),
      RepositoryGenerator(),
      // Add other generators as they are implemented
    ];
    
    for (final generator in generators) {
      print('\n🏭 Generating: ${generator.templateName}');
      
      try {
        final result = await generator.generate(options);
        combinedResult.merge(result);
        
        if (result.errors.isNotEmpty) {
          print('  ⚠️  ${result.errors.length} errors');
        } else {
          print('  ✅ ${result.filesGenerated} files generated');
        }
        
      } catch (e) {
        combinedResult.errors.add('${generator.templateName}: $e');
      }
    }
    
    return combinedResult;
  }
}

// Data structures
class GenerationOptions {
  List<String> entities = [];
  String outputDir = 'lib/generated';
  String? templateFile;
  bool dryRun = false;
  bool overwrite = false;
  String namingStyle = 'snake_case';
  List<String> features = [];
  
  @override
  String toString() {
    final options = <String>[];
    if (entities.isNotEmpty) options.add('entities=${entities.join(',')}');
    options.add('output=$outputDir');
    if (templateFile != null) options.add('template=$templateFile');
    if (dryRun) options.add('dry-run');
    if (overwrite) options.add('overwrite');
    options.add('naming=$namingStyle');
    if (features.isNotEmpty) options.add('features=${features.join(',')}');
    return options.join(', ');
  }
}

class GenerationResult {
  int filesGenerated = 0;
  int linesGenerated = 0;
  int templatesApplied = 0;
  final List<String> errors = [];
  final List<String> generatedFiles = [];
  
  void merge(GenerationResult other) {
    filesGenerated += other.filesGenerated;
    linesGenerated += other.linesGenerated;
    templatesApplied += other.templatesApplied;
    errors.addAll(other.errors);
    generatedFiles.addAll(other.generatedFiles);
  }
}