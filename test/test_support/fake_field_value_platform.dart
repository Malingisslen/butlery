/// Makes `FieldValue.*` sentinels work against `FakeFirebaseFirestore`.
///
/// **The wall this removes.** `FieldValue.serverTimestamp()` (and every other
/// sentinel) resolves through `FieldValueFactoryPlatform.instance`, a
/// process-wide singleton. `BaseUnitTest.setupUnit()` touches cloud_firestore
/// early enough that the real `MethodChannelFieldValueFactory` wins the race, so
/// a later write through a fake database throws
///
///     type 'MethodChannelFieldValue' is not a subtype of type
///     'MockFieldValuePlatform' in type cast
///
/// deep inside the fake, where production code that catches broadly (most
/// best-effort denormalization writes do) swallows it and lands ZERO documents.
/// A suite in that state does not fail — it silently asserts nothing, which is
/// how `recipe_sharing_manager_test.dart` ended up carrying a `skip:` whose
/// stated reason was "no unit test in this harness can observe the document".
///
/// `BaseTest.setup()` calls [installFakeFieldValuePlatform] as its first
/// statement, so every suite going through `BaseUnitTest.setupUnit()` or
/// `setupUnitWithProductionLocator()` already wins the race — the ordering is
/// structural rather than a convention each `setUp` has to remember. A suite
/// that stands up cloud_firestore WITHOUT that bootstrap must still call this
/// itself, first. It is idempotent and process-wide, so calling it from several
/// suites is harmless.
library;

// ignore: implementation_imports
import 'package:fake_cloud_firestore/src/mock_field_value_factory_platform.dart';
// ignore: depend_on_referenced_packages
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';

bool _installed = false;

/// Point the platform FieldValue factory at fake_cloud_firestore's mock.
void installFakeFieldValuePlatform() {
  if (_installed) return;
  FieldValueFactoryPlatform.instance = MockFieldValueFactoryPlatform();
  _installed = true;
}
