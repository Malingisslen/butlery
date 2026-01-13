// lib/widgets/import/components/add_item_field.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';

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
    final theme = Theme.of(context);

    return TextFormField(
      controller: _controller,
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.hintText,
        border: OutlineInputBorder(
          borderSide: BorderSide(
            color: theme.colorScheme.outline
                .withValues(alpha: AppDimensions.opacityHalf),
            style: BorderStyle.solid,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingMs,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            Icons.add_circle,
            color: theme.colorScheme.primary,
          ),
          onPressed: _add,
          tooltip: 'Lägg till',
        ),
      ),
      textCapitalization: TextCapitalization.sentences,
      onFieldSubmitted: (_) => _add(),
    );
  }
}
