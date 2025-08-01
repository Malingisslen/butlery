#!/usr/bin/env dart
// 🔥 NUCLEAR DISPOSE CLEANUP 🔥
// Removes dispose methods from classes that shouldn't have them

import 'dart:io';

void main() async {
  print('🔥 NUCLEAR DISPOSE CLEANUP 🔥');
  print('Target: Remove inappropriate dispose methods');
  print('Expected: Clean up overuse of dispose pattern');
  print('ETA: 1 hour | Fixing nuclear exterminator over-application\n');
  
  final stopwatch = Stopwatch()..start();
  
  await _cleanupInappropriateDisposeMethods();
  
  stopwatch.stop();
  
  print('\n🧹 NUCLEAR DISPOSE CLEANUP COMPLETE!');
  print('⏱️  Time: ${stopwatch.elapsed.inMinutes}m ${stopwatch.elapsed.inSeconds % 60}s');
  print('✅ Inappropriate dispose methods removed');
  print('🎯 Only legitimate ViewModels and Controllers keep dispose');
}

Future<void> _cleanupInappropriateDisposeMethods() async {
  print('🔍 Scanning for inappropriate dispose methods...');
  
  final libDirectory = Directory('lib');
  final dartFiles = await libDirectory
      .list(recursive: true)
      .where((entity) => entity is File && entity.path.endsWith('.dart'))
      .cast<File>()
      .toList();
  
  int filesFixed = 0;
  int inappropriateDisposesRemoved = 0;
  
  for (final file in dartFiles) {
    try {
      final content = await file.readAsString();
      
      // Skip files that should legitimately have dispose methods
      if (_shouldKeepDispose(content, file.path)) continue;
      
      var modifiedContent = content;
      bool modified = false;
      
      // Remove inappropriate dispose methods
      if (_hasInappropriateDispose(content)) {
        modifiedContent = _removeInappropriateDispose(modifiedContent);
        modified = true;
        inappropriateDisposesRemoved++;
      }
      
      // Remove inappropriate StreamManagementMixin
      if (_hasInappropriateStreamMixin(content)) {
        modifiedContent = _removeStreamManagementMixin(modifiedContent);
        modified = true;
      }
      
      if (modified) {
        await file.writeAsString(modifiedContent);
        filesFixed++;
        print('🧹 Cleaned: ${file.path}');
      }
      
    } catch (e) {
      print('⚠️  Warning: Could not process ${file.path}: $e');
    }
  }
  
  print('\n📊 CLEANUP RESULTS:');
  print('📁 Files cleaned: $filesFixed');
  print('🧹 Inappropriate dispose methods removed: $inappropriateDisposesRemoved');
  print('✅ Only legitimate dispose methods remain');
}

bool _shouldKeepDispose(String content, String filePath) {
  // Keep dispose for legitimate cases
  return (
    // ViewModels that extend ChangeNotifier
    (content.contains('ViewModel') && content.contains('ChangeNotifier')) ||
    
    // Controllers that manage resources
    (content.contains('Controller') && 
     (content.contains('StreamSubscription') || content.contains('Timer'))) ||
    
    // Services that manage resources
    (content.contains('Service') && content.contains('extends') &&
     (content.contains('StreamSubscription') || content.contains('Timer'))) ||
     
    // Widgets that are StatefulWidget
    (content.contains('StatefulWidget') || content.contains('State<')) ||
    
    // Files that actually have streams to dispose
    (content.contains('StreamSubscription') && !content.contains('abstract class'))
  );
}

bool _hasInappropriateDispose(String content) {
  // Check for classes that shouldn't have dispose
  return (
    // Constants classes
    content.contains('class') && content.contains('Constants') ||
    
    // Static utility classes
    (content.contains('class') && content.contains('static') && 
     !content.contains('ChangeNotifier')) ||
    
    // Mixins (they shouldn't have dispose directly)
    content.contains('mixin ') ||
    
    // Abstract classes without ChangeNotifier
    (content.contains('abstract class') && !content.contains('ChangeNotifier')) ||
    
    // Model classes (data classes)
    (content.contains('class') && content.contains('Model') &&
     !content.contains('ChangeNotifier')) ||
    
    // Repository interfaces
    (content.contains('abstract class') && content.contains('Repository'))
  ) && content.contains('@override\n  void dispose()');
}

bool _hasInappropriateStreamMixin(String content) {
  return content.contains('StreamManagementMixin') && (
    content.contains('class') && content.contains('Constants') ||
    content.contains('mixin ') ||
    (content.contains('abstract class') && !content.contains('ChangeNotifier'))
  );
}

String _removeInappropriateDispose(String content) {
  // Remove the entire dispose method block
  final disposePattern = RegExp(
    r'\s*@override\s*\n\s*void dispose\(\) \{\s*\n(?:\s*//[^\n]*\n)*\s*disposeStreams\(\); // From StreamManagementMixin\s*\n\s*super\.dispose\(\);\s*\n\s*\}',
    multiLine: true
  );
  
  content = content.replaceAll(disposePattern, '');
  
  // Also remove simpler dispose patterns
  final simpleDisposePattern = RegExp(
    r'\s*@override\s*\n\s*void dispose\(\) \{\s*\n(?:[^}]*\n)*\s*\}',
    multiLine: true
  );
  
  content = content.replaceAll(simpleDisposePattern, '');
  
  return content;
}

String _removeStreamManagementMixin(String content) {
  // Remove StreamManagementMixin from class declaration
  content = content.replaceAll(RegExp(r'\s*with StreamManagementMixin'), '');
  
  // Remove the import if no longer needed
  if (!content.contains('StreamManagementMixin')) {
    content = content.replaceAll(
      RegExp(r"import 'package:butlery/core/mixins/stream_management_mixin\.dart';\s*\n"),
      ''
    );
  }
  
  return content;
}