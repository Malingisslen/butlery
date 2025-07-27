// test/architecture/architecture_test.dart

import 'dart:io';
import 'package:test/test.dart';

void main() {
  group('Architecture Tests', () {
    test('Services should not import Firebase directly', () {
      final serviceFiles = Directory('lib/services')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.contains('test'));
      
      final violations = <String>[];
      
      for (final file in serviceFiles) {
        final content = file.readAsStringSync();
        
        // Check for direct Firebase imports
        if (content.contains("import 'package:cloud_firestore/cloud_firestore.dart'") ||
            content.contains('import "package:cloud_firestore/cloud_firestore.dart"')) {
          
          // Allow exceptions for repository implementations
          if (!file.path.contains('/repositories/')) {
            violations.add(file.path);
          }
        }
        
        // Check for direct FirebaseFirestore.instance usage
        if (content.contains('FirebaseFirestore.instance')) {
          violations.add('${file.path} - uses FirebaseFirestore.instance directly');
        }
      }
      
      if (violations.isNotEmpty) {
        fail('Architecture violations found:\n${violations.join('\n')}');
      }
    });
    
    test('ViewModels should not import Firebase', () {
      final viewModelFiles = Directory('lib/viewmodels')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      
      final violations = <String>[];
      
      for (final file in viewModelFiles) {
        final content = file.readAsStringSync();
        
        if (content.contains('package:cloud_firestore') ||
            content.contains('package:firebase_')) {
          violations.add(file.path);
        }
      }
      
      if (violations.isNotEmpty) {
        fail('ViewModels should not depend on Firebase directly:\n${violations.join('\n')}');
      }
    });
    
    test('Repositories should extend BaseFirebaseRepository', () {
      final repoFiles = Directory('lib/repositories/firebase')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.contains('base_firebase_repository.dart'));
      
      final violations = <String>[];
      
      for (final file in repoFiles) {
        final content = file.readAsStringSync();
        
        // Check if it's a repository implementation
        if (content.contains('implements') && content.contains('Repository')) {
          // Should extend BaseFirebaseRepository
          if (!content.contains('extends BaseFirebaseRepository')) {
            violations.add(file.path);
          }
        }
      }
      
      if (violations.isNotEmpty) {
        fail('Firebase repositories should extend BaseFirebaseRepository:\n${violations.join('\n')}');
      }
    });
    
    test('All services should use dependency injection', () {
      final serviceFiles = Directory('lib/services')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.contains('test'));
      
      final violations = <String>[];
      
      for (final file in serviceFiles) {
        final content = file.readAsStringSync();
        
        // Check for static methods that should be instance methods
        if (content.contains('static Future') && 
            !file.path.contains('deep_link_service.dart')) { // Exception for legacy code
          // Check if this is a service class
          if (content.contains('Service {') || content.contains('Service{')) {
            violations.add('${file.path} - contains static methods that should use DI');
          }
        }
      }
      
      if (violations.isNotEmpty) {
        fail('Services should use dependency injection instead of static methods:\n${violations.join('\n')}');
      }
    });
    
    test('File size limit check', () {
      final allDartFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.endsWith('.g.dart')); // Exclude generated files
      
      final violations = <String>[];
      const maxLines = 500;
      
      for (final file in allDartFiles) {
        final lines = file.readAsLinesSync().length;
        if (lines > maxLines) {
          violations.add('${file.path} - $lines lines (max: $maxLines)');
        }
      }
      
      if (violations.isNotEmpty) {
        // ignore: avoid_print - test output
        print('Warning: Files exceeding $maxLines lines:\n${violations.join('\n')}');
      }
    });
    
    test('MVVM: ViewModels should not contain UI logic', () {
      final viewModelFiles = Directory('lib/viewmodels')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      
      final violations = <String>[];
      
      for (final file in viewModelFiles) {
        final content = file.readAsStringSync();
        
        // Check for UI-specific imports that shouldn't be in ViewModels
        if (content.contains('package:flutter/material.dart') ||
            content.contains('package:flutter/cupertino.dart') ||
            content.contains('package:flutter/widgets.dart')) {
          
          // Allow exceptions for specific cases like Colors or Icons
          if (!content.contains('// UI imports allowed') &&
              !file.path.contains('theme')) {
            violations.add('${file.path} - contains UI imports');
          }
        }
        
        // Check for direct widget references
        if (content.contains('Widget ') || 
            content.contains('BuildContext') ||
            content.contains('showDialog') ||
            content.contains('Navigator')) {
          violations.add('${file.path} - contains UI logic');
        }
      }
      
      if (violations.isNotEmpty) {
        fail('ViewModels should not contain UI logic:\n${violations.join('\n')}');
      }
    });
    
    test('MVVM: Views should not contain business logic', () {
      final viewFiles = Directory('lib/views')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      
      final violations = <String>[];
      
      for (final file in viewFiles) {
        final content = file.readAsStringSync();
        
        // Check for direct Firebase usage
        if (content.contains('FirebaseFirestore') ||
            content.contains('FirebaseAuth') ||
            content.contains('FirebaseStorage')) {
          violations.add('${file.path} - contains direct Firebase usage');
        }
        
        // Check for complex business logic patterns
        if (content.contains('repository.') && 
            !content.contains('viewModel.')) {
          violations.add('${file.path} - directly accesses repository');
        }
        
        // Check for direct service calls (except through ViewModels)
        if ((content.contains('Service(') || content.contains('Service.')) &&
            !content.contains('viewModel') &&
            !content.contains('sl<')) {
          violations.add('${file.path} - contains direct service calls');
        }
      }
      
      if (violations.isNotEmpty) {
        fail('Views should not contain business logic:\n${violations.join('\n')}');
      }
    });
    
    test('Single Responsibility: Services should have focused responsibilities', () {
      final serviceFiles = Directory('lib/services')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => f.path.contains('service'));
      
      final violations = <String>[];
      
      for (final file in serviceFiles) {
        final content = file.readAsStringSync();
        final className = _extractClassName(content);
        
        if (className != null) {
          // Count public methods (rough estimate of responsibilities)
          final publicMethodCount = 'Future<'.allMatches(content).length +
                                   'Stream<'.allMatches(content).length +
                                   'void '.allMatches(content).length;
          
          // Services with too many methods likely violate SRP
          if (publicMethodCount > 15) {
            violations.add('${file.path} - $className has $publicMethodCount public methods (consider splitting)');
          }
          
          // Check for mixed responsibilities
          final hasAuthLogic = content.contains('auth') || content.contains('Auth');
          final hasDataLogic = content.contains('save') || content.contains('update') || content.contains('delete');
          final hasUILogic = content.contains('show') || content.contains('display');
          final hasNetworkLogic = content.contains('http') || content.contains('Http');
          
          int responsibilityCount = 0;
          if (hasAuthLogic) responsibilityCount++;
          if (hasDataLogic) responsibilityCount++;
          if (hasUILogic) responsibilityCount++;
          if (hasNetworkLogic) responsibilityCount++;
          
          if (responsibilityCount > 1 && !file.path.contains('unified')) {
            violations.add('${file.path} - $className appears to have multiple responsibilities');
          }
        }
      }
      
      if (violations.isNotEmpty) {
        // ignore: avoid_print - test output
        print('Warning: Services potentially violating Single Responsibility Principle:\n${violations.join('\n')}');
      }
    });
    
    test('Repository Pattern: Repositories should only handle data access', () {
      final repoFiles = Directory('lib/repositories')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.contains('interface'));
      
      final violations = <String>[];
      
      for (final file in repoFiles) {
        final content = file.readAsStringSync();
        
        // Repositories shouldn't contain business logic
        if (content.contains('calculate') ||
            content.contains('validate') && !content.contains('validatePermission') ||
            content.contains('transform') && !content.contains('fromFirestore')) {
          violations.add('${file.path} - contains business logic');
        }
        
        // Repositories shouldn't handle UI concerns
        if (content.contains('Widget') ||
            content.contains('BuildContext') ||
            content.contains('showDialog')) {
          violations.add('${file.path} - contains UI logic');
        }
        
        // Repositories shouldn't handle authentication (except AuthRepository)
        if (!file.path.contains('auth_repository') &&
            (content.contains('signIn') || 
             content.contains('signOut') || 
             content.contains('currentUser'))) {
          violations.add('${file.path} - handles authentication');
        }
      }
      
      if (violations.isNotEmpty) {
        fail('Repositories should only handle data access:\n${violations.join('\n')}');
      }
    });
  });
}

String? _extractClassName(String content) {
  final classMatch = RegExp(r'class\s+(\w+)').firstMatch(content);
  return classMatch?.group(1);
}