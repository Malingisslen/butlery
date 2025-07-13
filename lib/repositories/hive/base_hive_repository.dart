/// 🔍 AI INFO BLOCK:
/// Component: Base Hive repository
/// File: repositories/hive/base_hive_repository.dart
/// Quick Guide: Generic helper for storing models in Hive boxes
/// Dependencies IN: hive_flutter
/// Dependencies OUT: concrete Hive repositories
/// Data flow: Initialize box -> CRUD operations -> close box
/// State management: none
/// Purpose: Provide shared Hive box utilities
/// Common issues: forgetting to init before use
/// Test coverage: none yet
/// Performance: minimal I/O bound
/// Analytics: none
/// Code smells: none known
/// Connected to: recipe_hive_repository.dart
/// Used in phases: offline storage prototype

import 'package:hive_flutter/hive_flutter.dart';

/// Bas-klass för Hive-repositories med generisk CRUD-logik.
abstract class BaseHiveRepository<T> {
  /// Namnet på Hive-boxen
  final String boxName;

  /// Öppnad Hive-box
  Box<T>? _box;

  BaseHiveRepository(this.boxName);

  /// Initialiserar boxen om den inte redan är öppen
  Future<void> init() async {
    _box ??= await Hive.openBox<T>(boxName);
  }

  /// Accessor för den öppna boxen
  Box<T> get box {
    if (_box == null) {
      throw StateError('Hive-box $boxName är inte initialiserad');
    }
    return _box!;
  }

  /// Hämtar alla objekt i boxen
  List<T> getAll() => box.values.toList();

  /// Hämtar ett objekt via nyckel
  T? get(dynamic key) => box.get(key);

  /// Sparar eller uppdaterar ett objekt
  Future<void> put(dynamic key, T value) async => box.put(key, value);

  /// Tar bort ett objekt
  Future<void> delete(dynamic key) async => box.delete(key);

  /// Tömmer boxen helt
  Future<void> clear() async => box.clear();

  /// Stänger boxen
  Future<void> dispose() async => _box?.close();
}

