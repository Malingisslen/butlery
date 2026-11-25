// Kärnflöde steg 9C: read the pantry, plan, ask, write, offer Ångra. With
// meal boxes on (BUT-2486, part 5) leftovers join the same sheet.
library;

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/captured_snackbars.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/menu/meal_box.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/menu/meal_box_service.dart';
import 'package:butlery/services/pantry/cooked_pantry_plan.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/user_service/user_service_roles.dart';
import 'package:butlery/views/pantry/cooked_pantry_sheet.dart';
import 'package:butlery/widgets/pantry/meal_boxes/cooked_leftovers_sheet.dart';
import 'package:butlery/widgets/pantry/meal_boxes/meal_box_ui.dart';

typedef CookedPantrySheetOpener =
    Future<List<CookedPantryTake>?> Function(
      BuildContext context,
      List<CookedPantryTake> takes,
      int portions,
    );

typedef CookedLeftoversSheetOpener =
    Future<CookedLeftoversResult?> Function(
      BuildContext context,
      CookedLeftoversOffer offer,
    );

class CookedPantryFlow {
  /// The seams exist for tests; the app uses the defaults.
  CookedPantryFlow({
    PantryService Function()? service,
    String? Function()? userId,
    CookedPantrySheetOpener? openSheet,
    CookedLeftoversSheetOpener? openLeftoversSheet,
    MealBoxService Function()? mealBoxes,
    int? Function()? householdSize,
    bool Function()? mealBoxesOn,
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
           )),
       _openLeftoversSheet = openLeftoversSheet ?? showCookedLeftoversSheet,
       _mealBoxes = mealBoxes ?? ServiceLocator.get<MealBoxService>,
       _householdSize = householdSize ?? _profileHouseholdSize,
       _mealBoxesOn = mealBoxesOn ?? mealBoxesEnabled;

  final PantryService Function() _service;
  final String? Function() _userId;
  final CookedPantrySheetOpener _openSheet;
  final CookedLeftoversSheetOpener _openLeftoversSheet;
  final MealBoxService Function() _mealBoxes;
  final int? Function() _householdSize;
  final bool Function() _mealBoxesOn;

  static int? _profileHouseholdSize() {
    try {
      return ServiceLocator.tryGet<OwnProfileReader>()
          ?.currentUserProfile
          ?.householdSize;
    } catch (_) {
      return null;
    }
  }

  /// Leftovers are what [portions] has over the household's own meal, and
  /// the offer needs a dish name and a known household.
  int? _leftovers(Recipe recipe, int portions) {
    if (!_mealBoxesOn() || recipe.title.trim().isEmpty) return null;
    final eaters = _householdSize();
    if (eaters == null || eaters < 1) return null;
    final left = portions - eaters;
    return left >= 1 ? left : null;
  }

  /// Offers to take what [recipe] used at [portions] out of the pantry, and
  /// with meal boxes on, to keep what was left over. Shows nothing when
  /// signed out, or when neither half has anything to offer.
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

    final leftovers = _leftovers(recipe, portions);

    var pantry = const <PantryItem>[];
    try {
      pantry = await _service().getAll(userId);
    } catch (e) {
      AppLogger.warning('Cooked pantry offer: pantry unreadable: $e');
    }
    final plan = CookedPantryPlan.of(
      recipe,
      portions: portions,
      pantry: pantry,
    );
    if (!context.mounted) return;

    List<CookedPantryTake> chosen;
    var boxCount = 0;
    var location = MealBoxLocation.fridge;
    if (leftovers != null) {
      logMealBoxEvent(AnalyticsEvents.mealBoxOfferShown);
      final result = await _openLeftoversSheet(
        context,
        CookedLeftoversOffer(
          portions: portions,
          eaters: _householdSize()!,
          defaultCount: leftovers.clamp(1, MealBox.maxCount),
          pantryTakes: plan,
          editPantry: (sheetContext, current) => showCookedPantrySheet(
            sheetContext,
            takes: plan,
            selected: current,
            portions: portions,
            allowEmpty: true,
          ),
        ),
      );
      if (result == null) return;
      chosen = result.pantryTakes;
      boxCount = result.boxes;
      location = result.location;
    } else {
      if (plan.isEmpty) return;
      final picked = await _openSheet(context, plan, portions);
      if (picked == null) return;
      chosen = picked;
    }
    if (chosen.isEmpty && boxCount == 0) return;

    String? boxId;
    var boxFailed = false;
    if (boxCount > 0) {
      try {
        boxId = await _mealBoxes().add(
          MealBox(
            id: '',
            recipeId: recipe.id,
            recipeTitle: recipe.title,
            location: location,
            storedOn: clock.now(),
            count: boxCount,
          ),
        );
        logMealBoxEvent(
          AnalyticsEvents.mealBoxOfferSaved,
          parameters: {'count': boxCount, 'location': location.name},
        );
      } catch (e) {
        AppLogger.error('Meal box save failed: $e');
        boxFailed = true;
      }
    }

    var written = const <CookedPantryTake>[];
    var pantryFailed = false;
    if (chosen.isNotEmpty) {
      final service = _service();
      try {
        written = await service.takeCooked(userId, chosen);
      } on CookedPantryTakeFailed catch (e) {
        AppLogger.error('Cooked pantry take failed: $e');
        written = e.written;
        pantryFailed = true;
      } catch (e) {
        AppLogger.error('Cooked pantry take failed: $e');
        pantryFailed = true;
      }
    }

    final savedBoxId = boxId;
    Future<void> undoAll() async {
      if (savedBoxId != null) {
        try {
          await _mealBoxes().remove(savedBoxId);
        } catch (e) {
          AppLogger.error('Meal box undo failed: $e');
          snackBars.showFailure(what: l10n.mealBoxUndoFailed);
        }
      }
      if (written.isNotEmpty) {
        try {
          await _service().undoTakeCooked(userId, written);
        } catch (e) {
          AppLogger.error('Cooked pantry undo failed: $e');
          snackBars.showFailure(what: l10n.cookedPantryUndoFailed);
        }
      }
    }

    final anythingWritten = savedBoxId != null || written.isNotEmpty;
    if (boxFailed || pantryFailed) {
      final what = boxFailed && pantryFailed && !anythingWritten
          ? l10n.mealBoxAndPantryFailed
          : boxFailed
          ? l10n.mealBoxSaveFailed
          : l10n.cookedPantryFailed;
      if (anythingWritten) {
        undo.show(what, onUndo: undoAll);
      } else {
        snackBars.showFailure(what: what);
      }
      return;
    }
    final message = savedBoxId == null
        ? l10n.cookedPantryTaken(written.length)
        : written.isEmpty
        ? (location == MealBoxLocation.freezer
              ? l10n.mealBoxSavedFreezer(boxCount)
              : l10n.mealBoxSavedFridge(boxCount))
        : l10n.mealBoxSavedWithPantry(boxCount, written.length);
    undo.show(message, onUndo: undoAll);
  }
}
