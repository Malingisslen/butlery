import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/viewmodels/admin/ingredient_review_viewmodel.dart';

/// Puts the ingredient's correction prompt on the clipboard, so a fix can reach
/// Claude before in-app proposals exist.
Future<void> copyIngredientForClaude(
  BuildContext context,
  IngredientReviewViewModel vm,
  IngredientData ingredient,
) async {
  final confirmation = context.l10n.adminCopiedForClaude;
  final failure = context.l10n.adminCopyFailed;
  try {
    await Clipboard.setData(ClipboardData(text: vm.claudeTextFor(ingredient)));
  } catch (_) {
    if (!context.mounted) return;
    SnackBarUtils.showFailure(context, what: failure);
    return;
  }
  if (!context.mounted) return;
  SnackBarUtils.showSuccess(context, confirmation);
}
