// lib/widgets/import/components/add_item_field.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/styled/butlery_row_field.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';

/// Text field for adding new items to a list.
class AddItemField extends StatefulWidget {
  final String hintText;
  final void Function(String) onAdd;

  const AddItemField({
    super.key,
    required this.hintText,
    required this.onAdd,
  });

  @override
  State<AddItemField> createState() => _AddItemFieldState();
}

class _AddItemFieldState extends State<AddItemField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) {
      widget.onAdd(value);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ButleryRowField(
      controller: _controller,
      hintText: widget.hintText,
      maxLines: 1,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.done,
      textCapitalization: TextCapitalization.sentences,
      onFieldSubmitted: (_) => _add(),
      suffixIcon: AppIconButton(
        icon: ButleryIcons.plus,
        color: cs.onSurface,
        onPressed: _add,
        semanticLabel: context.l10n.commonAdd,
      ),
    );
  }
}
