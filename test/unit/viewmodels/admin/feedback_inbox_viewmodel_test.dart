/// Tests for FeedbackInboxViewModel — the admin inbox's stream wiring,
/// status filtering, pagination, and triage-status updates.
///
/// These prove the behaviours an admin actually relies on: switching the
/// filter re-queries from the first page, the stream's contents land in
/// [entries], pagination only offers "load more" when the page is full, and
/// a status change is forwarded to the repository. A bug in any of these
/// would show stale or wrong feedback in the dashboard.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/feedback_entry.dart';
import 'package:butlery/repositories/interfaces/feedback_repository.dart';
import 'package:butlery/viewmodels/admin/feedback_inbox_viewmodel.dart';

import '../../../test_support/base_unit_test.dart';

/// Fake repository that lets a test push feedback lists into the VM's stream
/// and records the filter/limit each subscription was opened with.
class _FakeFeedbackRepository implements FeedbackRepository {
  final _controller = StreamController<List<FeedbackEntry>>.broadcast();
  FeedbackStatus? lastStatus;
  int? lastLimit;
  final List<(String, FeedbackStatus)> statusUpdates = [];

  @override
  Stream<List<FeedbackEntry>> watchFeedback({
    FeedbackStatus? status,
    int limit = 50,
  }) {
    lastStatus = status;
    lastLimit = limit;
    return _controller.stream;
  }

  @override
  Future<void> updateStatus(String id, FeedbackStatus status) async {
    statusUpdates.add((id, status));
  }

  void emit(List<FeedbackEntry> entries) => _controller.add(entries);

  void emitError(Object error) => _controller.addError(error);

  Future<void> close() => _controller.close();

  @override
  Future<void> saveFeedback(FeedbackEntry entry) async =>
      throw UnimplementedError();

  @override
  Future<String> uploadScreenshot(String userId, Uint8List bytes) async =>
      throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> exportFeedbackByUser(
    String userId, {
    int maxDocuments = 1000,
  }) async =>
      throw UnimplementedError();
}

FeedbackEntry _entry(String id, {FeedbackStatus? status}) => FeedbackEntry(
      id: id,
      userId: 'u',
      category: FeedbackCategory.bug,
      description: 'd',
      recentInteractions: const [],
      createdAt: DateTime.utc(2026, 1, 1),
      status: status ?? FeedbackStatus.newReport,
    );

void main() {
  late _FakeFeedbackRepository repo;
  late FeedbackInboxViewModel vm;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  setUp(() {
    repo = _FakeFeedbackRepository();
    vm = FeedbackInboxViewModel(repository: repo);
  });

  tearDown(() async {
    vm.dispose();
    await repo.close();
  });

  test('start subscribes with no status filter and default page size', () {
    vm.start();
    expect(repo.lastStatus, isNull);
    expect(repo.lastLimit, 50);
  });

  test('stream contents land in entries', () async {
    vm.start();
    repo.emit([_entry('a'), _entry('b')]);
    await Future<void>.delayed(Duration.zero);
    expect(vm.entries.map((e) => e.id), ['a', 'b']);
  });

  test('setStatusFilter re-subscribes with that status from the first page',
      () async {
    vm.start();
    repo.emit([_entry('a')]);
    await Future<void>.delayed(Duration.zero);

    vm.setStatusFilter(FeedbackStatus.resolved);
    expect(repo.lastStatus, FeedbackStatus.resolved);
    expect(repo.lastLimit, 50); // page reset
  });

  test('canLoadMore is true only when the page is full', () async {
    vm.start();
    repo.emit(List.generate(50, (i) => _entry('e$i')));
    await Future<void>.delayed(Duration.zero);
    expect(vm.canLoadMore, isTrue);

    repo.emit([_entry('a')]);
    await Future<void>.delayed(Duration.zero);
    expect(vm.canLoadMore, isFalse);
  });

  test('loadMore raises the limit by one page', () async {
    vm.start();
    repo.emit(List.generate(50, (i) => _entry('e$i')));
    await Future<void>.delayed(Duration.zero);

    vm.loadMore();
    expect(repo.lastLimit, 100);
  });

  test('updateStatus forwards id + status to the repository', () async {
    vm.start();
    await vm.updateStatus('f1', FeedbackStatus.triaged);
    expect(repo.statusUpdates, [('f1', FeedbackStatus.triaged)]);
  });

  test('stream error sets error state', () async {
    vm.start();
    repo.emitError('boom');
    await Future<void>.delayed(Duration.zero);
    expect(vm.error, contains('boom'));
  });

  test('start() re-subscribes after an error (retry button works)', () async {
    vm.start();
    repo.emitError('boom');
    await Future<void>.delayed(Duration.zero);

    // Retry: start() must open a fresh subscription, not no-op on a stale one.
    repo.lastLimit = null;
    vm.start();
    expect(repo.lastLimit, 50);

    repo.emit([_entry('a')]);
    await Future<void>.delayed(Duration.zero);
    expect(vm.entries.map((e) => e.id), ['a']);
  });
}
