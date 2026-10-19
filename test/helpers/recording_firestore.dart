/// A real `FirebaseFirestore` over a recording platform, so a test can read the
/// conditions a query actually carries (BUT-1765).
///
/// Why it exists: `fake_cloud_firestore` does not run cloud_firestore's own
/// `Query.where` builder, which is where `isNotEqualTo: null` silently adds no
/// condition. A result-based test on the fake only reddens because the fake
/// throws on that argument, which is a property of the fake. Here the real
/// builder runs and hands its conditions to this platform, so an assertion is
/// about the filter the SDK built.
///
/// Usage: call [RecordingFirestore.install] once in `setUpAll` after
/// `setupFirebaseCoreMocks()` and `Firebase.initializeApp()`, BEFORE the first
/// `FirebaseFirestore.instance` is read (the SDK caches the instance).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// One query the code under test executed (`get()` or a `snapshots()` listen).
class RecordedQuery {
  RecordedQuery(this.path, Map<String, dynamic> parameters)
    : conditions = <String>[
        for (final c in (parameters['where'] as List).cast<List<dynamic>>())
          _describe(c),
      ],
      limit = parameters['limit'] as int?;

  final String path;

  /// Each condition as `field operator value`, e.g. `memberPermissions.alice != null`.
  final List<String> conditions;

  final int? limit;

  static String _describe(List<dynamic> condition) {
    final field = condition[0];
    final name = field is FieldPath ? field.components.join('.') : '$field';
    return '$name ${condition[1]} ${condition[2]}';
  }

  @override
  String toString() => '$path where $conditions limit $limit';
}

class RecordingFirestore {
  RecordingFirestore._(this._platform);

  final _RecordingPlatform _platform;

  /// Every query executed since the last [clear], in order.
  List<RecordedQuery> get executed => List.unmodifiable(_platform.executed);

  void clear() => _platform.executed.clear();

  /// The query executed on [path]; throws unless exactly one ran.
  RecordedQuery single(String path) {
    final matches = executed.where((q) => q.path == path).toList();
    if (matches.length != 1) {
      throw StateError(
        'expected one query on $path, saw ${matches.length}: $executed',
      );
    }
    return matches.single;
  }

  /// Registers the recording platform and returns the real SDK handle over it.
  static (RecordingFirestore, FirebaseFirestore) install() {
    final platform = _RecordingPlatform();
    FirebaseFirestorePlatform.instance = platform;
    return (RecordingFirestore._(platform), FirebaseFirestore.instance);
  }
}

class _RecordingPlatform extends FirebaseFirestorePlatform
    with MockPlatformInterfaceMixin {
  final List<RecordedQuery> executed = <RecordedQuery>[];

  @override
  FirebaseFirestorePlatform delegateFor({
    required FirebaseApp app,
    required String databaseId,
  }) => this;

  @override
  CollectionReferencePlatform collection(String collectionPath) =>
      _RecordingCollection(this, collectionPath);
}

QuerySnapshotPlatform _emptySnapshot() => QuerySnapshotPlatform(
  <DocumentSnapshotPlatform>[],
  <DocumentChangePlatform>[],
  SnapshotMetadataPlatform(false, false),
);

class _RecordingQuery extends QueryPlatform {
  _RecordingQuery(
    FirebaseFirestorePlatform firestore,
    this.queryPath,
    this.sink,
    Map<String, dynamic>? parameters,
  ) : super(firestore, parameters);

  final String queryPath;
  final List<RecordedQuery> sink;

  _RecordingQuery _with(Map<String, dynamic> change) => _RecordingQuery(
    firestore,
    queryPath,
    sink,
    Map<String, dynamic>.unmodifiable(
      Map<String, dynamic>.from(parameters)..addAll(change),
    ),
  );

  @override
  QueryPlatform where(List<List<dynamic>> conditions) =>
      _with(<String, dynamic>{'where': conditions});

  @override
  QueryPlatform limit(int limit) => _with(<String, dynamic>{'limit': limit});

  @override
  QueryPlatform orderBy(Iterable<List<dynamic>> orders) =>
      _with(<String, dynamic>{'orderBy': orders.toList()});

  @override
  Future<QuerySnapshotPlatform> get([
    GetOptions options = const GetOptions(),
  ]) async {
    sink.add(RecordedQuery(queryPath, parameters));
    return _emptySnapshot();
  }

  @override
  Stream<QuerySnapshotPlatform> snapshots({
    bool includeMetadataChanges = false,
    required ListenSource listenSource,
  }) async* {
    sink.add(RecordedQuery(queryPath, parameters));
    yield _emptySnapshot();
  }
}

class _RecordingCollection extends _RecordingQuery
    implements CollectionReferencePlatform {
  _RecordingCollection(_RecordingPlatform platform, String path)
    : _path = path,
      super(platform, path, platform.executed, null);

  final String _path;

  @override
  String get id => _path.split('/').last;

  @override
  String get path => _path;

  @override
  DocumentReferencePlatform? get parent => null;

  @override
  DocumentReferencePlatform doc([String? path]) =>
      throw UnimplementedError('the recording platform has no documents');
}
