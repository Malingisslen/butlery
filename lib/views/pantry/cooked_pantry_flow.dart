// Kärnflöde steg 9C: read the pantry, plan, ask, write, offer Ångra.
library;

import 'package:flutter/widgets.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/captured_snackbars.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/pantry/cooked_pantry_plan.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/views/pantry/cooked_pantry_sheet.dart';

typedef CookedPantrySheetOpener =
    Future<List<CookedPantryTake>?> Function(
      BuildContext context,
      List<CookedPantryTake> takes,
      int portions,
    );

class CookedPantryFlow {
  /// The seams exist for tests; the app uses the defaults.
  CookedPantryFlow({
    PantryService Function()? service,
    String? Function()? userId,
    CookedPantrySheetOpener? openSheet,
  }) : _service = service ?? ServiceLocator.get<PantryService>,
       _userId =
           userId ??
           (() => ServiceLocator.get<PermissionService>().currentUserId),
       _openSheet =
           openSheet ??
           ((context, takes, portions) => showCookedPantrySheet(
             context,
             takes: takes,
             portions: portions,
           ));

  final PantryService Function() _service;
  final String? Function() _userId;
  final CookedPantrySheetOpener _openSheet;

  /// Offers to take what [recipe] used at [portions] out of the pantry.
  /// Shows nothing when signed out, when the pantry cannot be read, or when
  /// the recipe uses nothing the pantry holds.
  Future<void> offer(
    BuildContext context,
    Recipe recipe, {
    required int portions,
  }) async {
    final userId = _userId();
    if (userId == null || userId.isEmpty) return;

    // Taken before the awaits: the sheet and the writes outlive this build.
    final undo = UndoSnackBar.capture(context);
    final snackBars = CapturedSnackBars.capture(context);
    final l10n = context.l10n;

    final List<PantryItem> pantry;
    try {
      pantry = await _service().getAll(userId);
    } catch (e) {
      AppLogger.warning('Cooked pantry offer skipped, pantry unreadable: $e');
      return;
    }
    final plan = CookedPantryPlan.of(
      recipe,
      portions: portions,
      pantry: pantry,
    );
    if (plan.isEmpty || !context.mounted) return;

    final chosen = await _openSheet(context, plan, portions);
    if (chosen == null || chosen.isEmpty) return;

    final service = _service();
    Future<void> undoWritten(List<CookedPantryTake> written) async {
      try {
        await service.undoTakeCooked(userId, written);
      } catch (e) {
        AppLogger.error('Cooked pantry undo failed: $e');
        snackBars.showFailure(what: l10n.cookedPantryUndoFailed);
      }
    }

    var written = const <CookedPantryTake>[];
    var failed = false;
    try {
      written = await service.takeCooked(userId, chosen);
    } on CookedPantryTakeFailed catch (e) {
      AppLogger.error('Cooked pantry take failed: $e');
      written = e.written;
      failed = true;
    } catch (e) {
      AppLogger.error('Cooked pantry take failed: $e');
      failed = true;
    }

    if (failed) {
      if (written.isEmpty) {
        snackBars.showFailure(what: l10n.cookedPantryFailed);
      } else {
        undo.show(l10n.cookedPantryFailed, onUndo: () => undoWritten(written));
      }
      return;
    }
    undo.show(
      l10n.cookedPantryTaken(written.length),
      onUndo: () => undoWritten(written),
    );
  }
}
