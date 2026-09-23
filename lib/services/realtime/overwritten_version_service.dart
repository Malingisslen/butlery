/// P5-U26b: "Återställ" for an overwritten version, within 30 days.
///
/// produktregler.md:104 (week menu: "30 s snackbar · därefter Återställ i 30
/// dagar") and :109 (the overwritten version is kept for 30 days and reached
/// through Återställ). RealtimeSyncService keeps the version when the user's
/// save loses; this service lists what can still be restored and restores it.
///
/// Restoring replaces what another person saved, which is content that is
/// gone once the undo window closes, so it is the hard-destructive class of
/// BUT-954 (.claude/rules/ui-conventions.md:137): the surface asks first, then
/// offers Ångra for 7 s. [restore] writes at once and returns what it replaced;
/// [undo] puts that back; [settle] runs when the undo window has closed
/// without Ångra and forgets the kept row, since the version it held is the
/// live one again.
library;

import 'package:clock/clock.dart';

import 'package:butlery/models/realtime/overwritten_version.dart';
import 'package:butlery/models/realtime/realtime_menu.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/repositories/interfaces/overwritten_version_repository.dart';
import 'package:butlery/services/realtime_sync_service.dart';

/// What a restore replaced, so it can be undone.
class OverwrittenVersionRestore {
  const OverwrittenVersionRestore({
    required this.version,
    required this.replaced,
  });

  /// The kept version that is now live again.
  final OverwrittenVersion version;

  /// The version that was live before the restore.
  final RealtimeResource replaced;
}

/// Thrown when the resource the version belongs to no longer exists, so
/// there is nothing to restore it into. The kept version is left in place.
class OverwrittenVersionTargetMissing implements Exception {
  const OverwrittenVersionTargetMissing(this.resourceId);

  final String resourceId;

  @override
  String toString() => 'OverwrittenVersionTargetMissing($resourceId)';
}

class OverwrittenVersionService {
  OverwrittenVersionService({
    required OverwrittenVersionRepository repository,
    required RealtimeSyncService syncService,
  }) : _repository = repository,
       _sync = syncService;

  final OverwrittenVersionRepository _repository;
  final RealtimeSyncService _sync;

  /// The signed-in user's kept versions for [entity] (and [resourceId] when
  /// given), newest first, without any that are past their 30 days.
  Stream<List<OverwrittenVersion>> watch({
    required ConflictEntity entity,
    String? resourceId,
  }) =>
      _repository.watch(entity: entity, resourceId: resourceId).map(stillKept);

  /// [versions] without those whose 30 days have passed at [clock.now].
  static List<OverwrittenVersion> stillKept(List<OverwrittenVersion> versions) {
    final now = clock.now();
    return [
      for (final v in versions)
        if (v.isKeptAt(now)) v,
    ];
  }

  /// Makes [version] the live one again and returns what it replaced.
  ///
  /// The restored content is written on top of the current version's edit
  /// counter (RealtimeSyncService.recoverLocalVersion), so it wins the next
  /// comparison instead of losing again. The kept row stays until [settle].
  Future<OverwrittenVersionRestore> restore(OverwrittenVersion version) async {
    final current = await _sync.fetchLatestResource<RealtimeResource>(
      version.resourceId,
    );
    if (current == null) {
      throw OverwrittenVersionTargetMissing(version.resourceId);
    }
    await _sync.recoverLocalVersion<RealtimeResource>(parse(version));
    return OverwrittenVersionRestore(version: version, replaced: current);
  }

  /// Puts back the version [receipt] replaced. The kept version stays kept.
  Future<void> undo(OverwrittenVersionRestore receipt) =>
      _sync.recoverLocalVersion<RealtimeResource>(receipt.replaced);

  /// The undo window closed without Ångra: the kept version is live, so its
  /// row is no longer needed.
  Future<void> settle(OverwrittenVersionRestore receipt) =>
      _repository.forget(receipt.version.id);

  /// The kept version as the resource it was.
  static RealtimeResource parse(OverwrittenVersion version) =>
      switch (version.resourceType) {
        RealtimeResourceType.recipe => RealtimeRecipe.fromMap(
          version.resourceId,
          version.version,
        ),
        RealtimeResourceType.menu => RealtimeMenu.fromMap(
          version.resourceId,
          version.version,
        ),
        RealtimeResourceType.shoppingList => throw UnsupportedError(
          'Shopping lists keep no overwritten versions (BUT-2140)',
        ),
      };
}
