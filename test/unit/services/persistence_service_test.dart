import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/services/persistence_service.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// Local extended MockSharedPreferences for testing with control methods
class TestMockSharedPreferences extends MockSharedPreferences {
  final Map<String, Object> _data = {};
  bool _shouldThrow = false;

  // Control method for simulating errors
  void setShouldThrow(bool value) {
    _shouldThrow = value;
  }

  @override
  Future<bool> setString(String key, String value) async {
    if (_shouldThrow) throw Exception('Storage error');
    _data[key] = value;
    return true;
  }

  @override
  String? getString(String key) {
    if (_shouldThrow) throw Exception('Storage error');
    return _data[key] as String?;
  }

  @override
  Future<bool> remove(String key) async {
    if (_shouldThrow) throw Exception('Storage error');
    _data.remove(key);
    return true;
  }

  @override
  Set<String> getKeys() {
    return _data.keys.toSet();
  }

  @override
  Future<bool> clear() async {
    if (_shouldThrow) throw Exception('Storage error');
    _data.clear();
    return true;
  }

  // Helper methods for testing
  void setData(String key, String value) {
    _data[key] = value;
  }

  void clearData() {
    _data.clear();
  }

  bool hasKey(String key) {
    return _data.containsKey(key);
  }
}

void main() {
  late PersistenceService service;
  late TestMockSharedPreferences mockPrefs;

  setUpAll(() async {
    // Initialize base test infrastructure for consistency
    await BaseUnitTest.setupUnit();
  });

  setUp(() {
    mockPrefs = TestMockSharedPreferences();
    SharedPreferences.setMockInitialValues({});

    // Override SharedPreferences.getInstance to return our mock
    // Note: In real implementation, we'd inject SharedPreferences through constructor
    // For now, we'll test the service as-is
    service = PersistenceService();
  });

  tearDown(() async {
    mockPrefs.clearData();
    mockPrefs.setShouldThrow(false);
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  group('PersistenceService', () {
    // BUT-1028: recipe-list scroll-offset persistence (View-layer restore).
    group('Recipe-list scroll offset', () {
      test('returns 0.0 when nothing has been persisted', () async {
        SharedPreferences.setMockInitialValues({});

        expect(await service.getRecipeListScrollOffset(), 0.0);
      });

      test('round-trips a saved offset', () async {
        SharedPreferences.setMockInitialValues({});

        await service.setRecipeListScrollOffset(1234.5);

        expect(await service.getRecipeListScrollOffset(), 1234.5);
      });

      test('overwrites a previous offset', () async {
        SharedPreferences.setMockInitialValues({});

        await service.setRecipeListScrollOffset(800.0);
        await service.setRecipeListScrollOffset(42.0);

        expect(await service.getRecipeListScrollOffset(), 42.0);
      });
    });
  });
}
