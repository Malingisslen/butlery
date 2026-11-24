import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/shopping/shopping_dietary_hints_controller.dart';
import 'package:butlery/widgets/shopping/shopping_dietary_hint_box.dart';

/// Owns the allergy reminders for one shopping list on screen (BUT-2494):
/// creates the controller, feeds it the list's open rows whenever [source]
/// changes, and provides it to the rows below.
class ShoppingDietaryHintsScope extends StatefulWidget {
  const ShoppingDietaryHintsScope({
    required this.source,
    required this.rows,
    required this.child,
    this.controller,
    super.key,
  });

  /// Notifies when the list's rows change (the list's view model).
  final Listenable source;

  /// The open rows right now. Ticked rows get no reminder.
  final List<UnifiedShoppingItem> Function() rows;

  final Widget child;

  /// For tests; built from the service locator when null.
  final ShoppingDietaryHintsController? controller;

  @override
  State<ShoppingDietaryHintsScope> createState() =>
      _ShoppingDietaryHintsScopeState();
}

class _ShoppingDietaryHintsScopeState extends State<ShoppingDietaryHintsScope> {
  late final ShoppingDietaryHintsController _controller =
      widget.controller ?? ShoppingDietaryHintsController.fromLocator();

  @override
  void initState() {
    super.initState();
    widget.source.addListener(_onSource);
    // After the first frame: the list paints before any lookup starts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onSource();
    });
  }

  @override
  void didUpdateWidget(ShoppingDietaryHintsScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      oldWidget.source.removeListener(_onSource);
      widget.source.addListener(_onSource);
    }
  }

  void _onSource() {
    _controller.update([
      for (final item in widget.rows())
        if (!item.bought) (id: item.id, name: item.name),
    ]);
  }

  @override
  void dispose() {
    widget.source.removeListener(_onSource);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ChangeNotifierProvider<ShoppingDietaryHintsController>.value(
        value: _controller,
        child: widget.child,
      );
}

/// The reminders under [item]'s row, or null when it has none: what a row
/// passes as `ShoppingRow.below`.
Widget? shoppingDietaryHintsBelow(
  BuildContext context,
  UnifiedShoppingItem item, {
  required bool completed,
}) {
  if (completed) return null;
  final controller = context.watch<ShoppingDietaryHintsController?>();
  if (controller == null) return null;
  final hints = controller.hintsFor(item.id);
  if (hints.isEmpty) return null;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final hint in hints)
        ShoppingDietaryHintBox(
          key: ValueKey('shopping-hint-${item.id}-${hint.choiceKey}'),
          hint: hint,
          onDismiss: () {
            final l10n = context.l10n;
            controller.dismiss(item.id, hint.choiceKey);
            SnackBarUtils.showUndo(
              context,
              l10n.shoppingHintDismissed(item.name),
              onUndo: () => controller.undoDismiss(item.id, hint.choiceKey),
            );
          },
        ),
    ],
  );
}

/// "Påminnelser kan saknas. Läs alltid innehållet." at the top of the list,
/// shown whenever a reminder is (Malin 2026-11-24, ADR-0044): a row without a
/// box is not a row that is free of anything.
class ShoppingDietaryHintsNotice extends StatelessWidget {
  const ShoppingDietaryHintsNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ShoppingDietaryHintsController?>();
    if (controller == null || !controller.hasVisibleHints) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.space8),
      child: Text(
        context.l10n.shoppingHintsDisclaimer,
        style: AppTextStyles.captionText.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
