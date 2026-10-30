// lib/widgets/menu/manual_add_confirm.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/menu/manual_add_check.dart';
import 'package:butlery/widgets/common/dialogs/confirmation_dialogs.dart';

/// Asks before recipes that conflict with the household's allergies or
/// dislikes go into the menu by hand. True means go ahead: nothing conflicts,
/// the person chose to add anyway, or the check itself failed. A failed check
/// must not block adding, but it is logged.
Future<bool> confirmManualAdd(
  BuildContext context,
  List<Recipe> recipes, {
  Future<List<ManualAddFinding>> Function(List<Recipe>)? findingsFor,
}) async {
  final List<ManualAddFinding> findings;
  try {
    findings = await (findingsFor ?? const ManualAddCheck().check)(recipes);
  } catch (e) {
    AppLogger.error('Manual add check failed', e);
    return true;
  }
  final blocking = findings.where((f) => f.needsConfirmation).toList();
  if (blocking.isEmpty || !context.mounted) return true;

  final l = context.l10n;
  final lines = <String>[
    for (final f in blocking) ...[
      if (f.containsAllergens.isNotEmpty)
        l.menuManualAddContains(f.recipe.title, f.containsAllergens.join(', ')),
      if (f.disliked) l.menuManualAddDislikes(f.recipe.title),
      if (f.uncheckedAllergens.isNotEmpty)
        l.menuManualAddUnchecked(f.recipe.title),
    ],
  ];
  return ConfirmationDialogs.showConfirmationDialog(
    context,
    title: l.menuManualAddTitle,
    message: lines.join('\n'),
    confirmText: l.menuManualAddConfirm,
  );
}
