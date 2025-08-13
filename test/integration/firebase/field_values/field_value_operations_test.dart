/// Integration tests for Firebase FieldValue operations
/// 
/// These tests run against Firebase Emulator to verify actual
/// server-side FieldValue behavior.
@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../setup/firebase_test_setup.dart';

void main() {
  group('Firebase FieldValue Operations', () {
    late FirebaseFirestore firestore;
    
    setUpAll(() async {
      await FirebaseTestSetup.initialize();
      firestore = FirebaseFirestore.instance;
    });
    
    setUp(() async {
      await FirebaseTestSetup.clearEmulatorData();
    });
    
    group('serverTimestamp', () {
      test('should set server timestamp on document creation', () async {
        // Act
        final docRef = await firestore.collection('test').add({
          'createdAt': FieldValue.serverTimestamp(),
          'name': 'Test Document',
        });
        
        // Assert
        final snapshot = await docRef.get();
        final data = snapshot.data()!;
        
        expect(data['createdAt'], isA<Timestamp>());
        expect(data['name'], equals('Test Document'));
        
        // Verify timestamp is recent (within last minute)
        final timestamp = data['createdAt'] as Timestamp;
        final now = DateTime.now();
        final difference = now.difference(timestamp.toDate());
        expect(difference.inMinutes, lessThan(1));
      });
      
      test('should update server timestamp on document update', () async {
        // Arrange
        final docRef = await firestore.collection('test').add({
          'name': 'Original',
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        // Wait a moment to ensure timestamps differ
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Act
        await docRef.update({
          'name': 'Updated',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Assert
        final snapshot = await docRef.get();
        final data = snapshot.data()!;
        
        expect(data['createdAt'], isA<Timestamp>());
        expect(data['updatedAt'], isA<Timestamp>());
        
        final created = (data['createdAt'] as Timestamp).toDate();
        final updated = (data['updatedAt'] as Timestamp).toDate();
        expect(updated.isAfter(created), isTrue);
      });
    });
    
    group('arrayUnion', () {
      test('should add unique items to array', () async {
        // Arrange
        final docRef = await firestore.collection('test').add({
          'tags': ['tag1', 'tag2'],
        });
        
        // Act
        await docRef.update({
          'tags': FieldValue.arrayUnion(['tag2', 'tag3', 'tag4']),
        });
        
        // Assert
        final snapshot = await docRef.get();
        final tags = List<String>.from(snapshot.data()!['tags']);
        
        expect(tags, containsAll(['tag1', 'tag2', 'tag3', 'tag4']));
        expect(tags.length, equals(4)); // No duplicates
      });
      
      test('should create array if it does not exist', () async {
        // Arrange
        final docRef = await firestore.collection('test').add({
          'name': 'Test',
        });
        
        // Act
        await docRef.update({
          'tags': FieldValue.arrayUnion(['new1', 'new2']),
        });
        
        // Assert
        final snapshot = await docRef.get();
        final tags = List<String>.from(snapshot.data()!['tags']);
        
        expect(tags, equals(['new1', 'new2']));
      });
    });
    
    group('arrayRemove', () {
      test('should remove items from array', () async {
        // Arrange
        final docRef = await firestore.collection('test').add({
          'tags': ['tag1', 'tag2', 'tag3', 'tag4'],
        });
        
        // Act
        await docRef.update({
          'tags': FieldValue.arrayRemove(['tag2', 'tag4']),
        });
        
        // Assert
        final snapshot = await docRef.get();
        final tags = List<String>.from(snapshot.data()!['tags']);
        
        expect(tags, equals(['tag1', 'tag3']));
      });
      
      test('should handle removing non-existent items', () async {
        // Arrange
        final docRef = await firestore.collection('test').add({
          'tags': ['tag1', 'tag2'],
        });
        
        // Act
        await docRef.update({
          'tags': FieldValue.arrayRemove(['tag3', 'tag4']),
        });
        
        // Assert
        final snapshot = await docRef.get();
        final tags = List<String>.from(snapshot.data()!['tags']);
        
        expect(tags, equals(['tag1', 'tag2']));
      });
    });
    
    group('increment', () {
      test('should increment numeric field', () async {
        // Arrange
        final docRef = await firestore.collection('test').add({
          'count': 5,
        });
        
        // Act
        await docRef.update({
          'count': FieldValue.increment(3),
        });
        
        // Assert
        final snapshot = await docRef.get();
        expect(snapshot.data()!['count'], equals(8));
      });
      
      test('should decrement with negative value', () async {
        // Arrange
        final docRef = await firestore.collection('test').add({
          'count': 10,
        });
        
        // Act
        await docRef.update({
          'count': FieldValue.increment(-3),
        });
        
        // Assert
        final snapshot = await docRef.get();
        expect(snapshot.data()!['count'], equals(7));
      });
      
      test('should create field if it does not exist', () async {
        // Arrange
        final docRef = await firestore.collection('test').add({
          'name': 'Test',
        });
        
        // Act
        await docRef.update({
          'count': FieldValue.increment(5),
        });
        
        // Assert
        final snapshot = await docRef.get();
        expect(snapshot.data()!['count'], equals(5));
      });
    });
    
    group('combined operations', () {
      test('should handle multiple FieldValue operations in single update', () async {
        // Arrange
        final docRef = await firestore.collection('test').add({
          'name': 'Test',
          'views': 100,
          'tags': ['existing'],
        });
        
        // Act
        await docRef.update({
          'updatedAt': FieldValue.serverTimestamp(),
          'views': FieldValue.increment(1),
          'tags': FieldValue.arrayUnion(['new1', 'new2']),
        });
        
        // Assert
        final snapshot = await docRef.get();
        final data = snapshot.data()!;
        
        expect(data['updatedAt'], isA<Timestamp>());
        expect(data['views'], equals(101));
        expect(List<String>.from(data['tags']), 
               containsAll(['existing', 'new1', 'new2']));
      });
    });
  });
}