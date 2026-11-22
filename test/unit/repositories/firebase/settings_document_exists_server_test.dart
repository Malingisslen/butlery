// BUT-2515: whether the settings document exists decides if a re-made profile
// may overwrite it, so the answer must come from the server. A document never
// cached on this device reads as missing offline, which would pick the
// overwrite. FakeFirebaseFirestore ignores GetOptions, so this pins the option
// with mocks.

// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/repositories/firebase/firebase_user_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _MockSnap extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  setUpAll(() => registerFallbackValue(const GetOptions()));

  test('the existence check asks the server, never the cache', () async {
    const uid = 'user-alice';
    final firestore = _MockFirestore();
    final collection = _MockCollection();
    final doc = _MockDoc();
    final snap = _MockSnap();
    when(() => firestore.collection(any())).thenReturn(collection);
    when(() => collection.doc(any())).thenReturn(doc);
    when(() => doc.collection(any())).thenReturn(collection);
    when(() => doc.get(any())).thenAnswer((_) async => snap);
    when(() => snap.exists).thenReturn(true);
    final auth = FakeAuthRepository()
      ..setAuthState(
        user: FakeUser(uid: uid),
        userId: uid,
        isAuthenticated: true,
      );
    final repo = FirebaseUserRepository(
      firestore: firestore,
      authRepository: auth,
    );

    expect(await repo.settingsDocumentExists(uid), isTrue);

    final options =
        verify(() => doc.get(captureAny())).captured.single as GetOptions?;
    expect(options?.source, Source.server);
  });
}
