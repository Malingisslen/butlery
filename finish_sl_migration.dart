/// Script to complete the migration from sl&lt;T&gt;() to ServiceLocator.get&lt;T&gt;()
/// This script will process all remaining Dart files in the lib directory

import 'dart:io';

// ignore_for_file: avoid_print

void main() async {
  stdout.writeln('🔧 Starting sl<T>() to ServiceLocator.get<T>() migration...');
  
  final libDir = Directory('lib');
  if (!await libDir.exists()) {
    print('❌ lib directory not found!');
    exit(1);
  }

  int filesUpdated = 0;
  int totalReplacements = 0;

  await for (final entity in libDir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final result = await processFile(entity);
      if (result > 0) {
        filesUpdated++;
        totalReplacements += result;
        print('✅ Updated ${entity.path} - $result replacements');
      }
    }
  }

  print('\n🎉 Migration complete!');
  print('📊 Files updated: $filesUpdated');
  print('📊 Total replacements: $totalReplacements');
  
  // Run flutter analyze to verify
  print('\n🔍 Running flutter analyze...');
  final analyzeResult = await Process.run('flutter', ['analyze']);
  if (analyzeResult.exitCode == 0) {
    print('✅ No analysis issues found!');
  } else {
    print('⚠️  Some analysis issues remain:');
    print(analyzeResult.stdout);
  }
}

Future<int> processFile(File file) async {
  try {
    var content = await file.readAsString();
    final originalContent = content;
    int replacements = 0;

    // Replace old injection import
    if (content.contains("import 'package:butlery/core/injection.dart';")) {
      content = content.replaceAll(
        "import 'package:butlery/core/injection.dart';",
        "import 'package:butlery/core/providers/application_provider.dart';"
      );
      replacements++;
    }

    // Replace sl<T>() calls with ServiceLocator.get<T>()
    final slRegex = RegExp(r'sl<([^>]+)>\(\)');
    final matches = slRegex.allMatches(content);
    
    for (final match in matches) {
      final fullMatch = match.group(0)!;
      final typeParam = match.group(1)!;
      content = content.replaceAll(fullMatch, 'ServiceLocator.get<$typeParam>()');
      replacements++;
    }

    // Only write if changes were made
    if (content != originalContent) {
      await file.writeAsString(content);
      return replacements;
    }

    return 0;
  } catch (e) {
    print('❌ Error processing ${file.path}: $e');
    return 0;
  }
}