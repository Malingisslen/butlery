import 'dart:async';

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/menu/menu_wish.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/field_text_style.dart';
import 'package:butlery/viewmodels/menu_wishes_viewmodel.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog.dart';
import 'package:butlery/widgets/common/dialogs/dialog_cancel_button.dart';
import 'package:butlery/widgets/common/input/labeled_field.dart';
import 'package:butlery/widgets/common/list/butlery_item_row.dart';
import 'package:butlery/widgets/common/section_heading.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';
import 'package:butlery/widgets/menu/veckomeny_quick_picks.dart';

/// "Mina önskemål": the user's saved wishes with rename and remove, then last
/// week's wish and the two built-ins as information. Returns the wish the
/// user tapped, for the caller to put in the prompt field.
///
/// The model is passed in because a sheet route sits above the view's
/// providers.
Future<MenuWishFill?> showMenuWishesSheet(
  BuildContext context, {
  required MenuWishesViewModel viewModel,
}) {
  return showButlerySheet<MenuWishFill>(
    context: context,
    builder: (_) => MenuWishesSheet(viewModel: viewModel, hostContext: context),
  );
}

class MenuWishesSheet extends StatelessWidget {
  const MenuWishesSheet({
    super.key,
    required this.viewModel,
    required this.hostContext,
  });

  final MenuWishesViewModel viewModel;

  /// The screen under the sheet, which owns the snackbars.
  final BuildContext hostContext;

  Future<void> _rename(BuildContext context, MenuWish wish) =>
      showButleryDialog<void>(
        context: context,
        builder: (_) => _RenameWishDialog(
          initial: wish.name,
          save: (name) => viewModel.rename(wish, name),
          failure: () => viewModel.error ?? context.l10n.menuWishSaveFailed,
        ),
      );

  // A modal sheet's barrier sits above the screen's snackbars, so a snackbar
  // with Ångra must wait until the sheet is closed: remove closes it.
  Future<void> _remove(BuildContext context, MenuWish wish) async {
    final index = viewModel.wishes.indexOf(wish);
    final removal = viewModel.remove(wish);
    Navigator.of(context).pop();
    SnackBarUtils.showUndo(
      hostContext,
      hostContext.l10n.menuWishRemoved,
      onUndo: () => unawaited(_undo(wish, index)),
    );
    if (!await removal && hostContext.mounted) {
      ScaffoldMessenger.of(hostContext).hideCurrentSnackBar();
      _showSaveFailure();
    }
  }

  Future<void> _undo(MenuWish wish, int index) async {
    if (!await viewModel.undoRemove(wish, index) && hostContext.mounted) {
      _showSaveFailure();
    }
  }

  void _showSaveFailure() {
    SnackBarUtils.showFailure(
      hostContext,
      what: viewModel.error ?? hostContext.l10n.menuWishSaveFailed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sheetContext = context;
    return SafeArea(
      child: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final l10n = context.l10n;
          final cs = Theme.of(context).colorScheme;
          final wishes = viewModel.wishes;
          final last = viewModel.lastWish;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.space16,
              0,
              AppDimensions.space16,
              AppDimensions.space16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.menuWishesSheetTitle,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: AppDimensions.space12),
                if (wishes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimensions.space8,
                    ),
                    child: Text(
                      l10n.menuWishesEmpty,
                      key: const ValueKey('menu-wishes-empty'),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                for (final wish in wishes)
                  _SavedWishRow(
                    key: ValueKey('menu-wish-${wish.id}'),
                    wish: wish,
                    onRename: () => unawaited(_rename(sheetContext, wish)),
                    onRemove: () => unawaited(_remove(sheetContext, wish)),
                  ),
                if (last != null) ...[
                  const SizedBox(height: AppDimensions.space12),
                  ButleryItemRow(
                    key: const ValueKey('menu-wish-last'),
                    title: l10n.menuWishLastTitle,
                    subtitle: last.text,
                    onTap: () => Navigator.of(context).pop(
                      MenuWishFill(
                        text: last.text,
                        pantryFocus: last.pantryFocus,
                        sourceId: VeckomenyQuickPicks.lastSourceId,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppDimensions.space12),
                SectionHeading(l10n.menuWishesBuiltInTitle),
                ButleryItemRow(title: l10n.menuQuickFastTitle),
                ButleryItemRow(title: l10n.menuQuickPantryTitle),
                Padding(
                  padding: const EdgeInsets.only(top: AppDimensions.space8),
                  child: Text(
                    l10n.menuWishesBuiltInNote,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SavedWishRow extends StatelessWidget {
  const _SavedWishRow({
    super.key,
    required this.wish,
    required this.onRename,
    required this.onRemove,
  });

  final MenuWish wish;
  final VoidCallback onRename;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ButleryItemRow(
          title: wish.name,
          subtitle: wish.text,
          onTap: () => Navigator.of(context).pop(
            MenuWishFill(
              text: wish.text,
              pantryFocus: false,
              sourceId: VeckomenyQuickPicks.savedSourceId(wish),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ButleryTextButton(
              label: l10n.menuWishRename,
              onPressed: onRename,
            ),
            ButleryTextButton(
              label: l10n.commonRemove,
              tone: ButleryTextButtonTone.danger,
              onPressed: onRemove,
            ),
          ],
        ),
      ],
    );
  }
}

class _RenameWishDialog extends StatefulWidget {
  const _RenameWishDialog({
    required this.initial,
    required this.save,
    required this.failure,
  });

  final String initial;
  final Future<bool> Function(String name) save;
  final String Function() failure;

  @override
  State<_RenameWishDialog> createState() => _RenameWishDialogState();
}

class _RenameWishDialogState extends State<_RenameWishDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await widget.save(name);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      _error = widget.failure();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ButleryDialog(
      title: l10n.menuWishRenameTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LabeledField(
            label: l10n.menuWishNameLabel,
            child: TextField(
              key: const ValueKey('menu-wish-name'),
              controller: _name,
              autofocus: true,
              enabled: !_saving,
              maxLength: MenuWishes.maxNameLength,
              style: fieldTextStyle(context, enabled: !_saving),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => unawaited(_submit()),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.space12),
              child: Text(
                _error!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
      actions: [
        DialogCancelButton(enabled: !_saving),
        ButleryDialogPrimary(
          label: l10n.commonSave,
          busy: _saving,
          onPressed: _name.text.trim().isEmpty || _saving
              ? null
              : () => unawaited(_submit()),
        ),
      ],
    );
  }
}
