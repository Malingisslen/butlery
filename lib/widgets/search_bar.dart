// lib/widgets/search_bar.dart

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppSearchBar extends StatefulWidget {
  final String hintText;
  final Function(String) onChanged;
  final VoidCallback? onClear;
  final TextEditingController? controller;
  final Widget? prefixIcon;
  final bool enabled;
  final String? initialValue;

  const AppSearchBar({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.onClear,
    this.controller,
    this.prefixIcon,
    this.enabled = true,
    this.initialValue,
  });

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late TextEditingController _controller;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();

    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
      _hasText = widget.initialValue!.isNotEmpty;
    }

    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_onTextChanged);
    }
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
    widget.onChanged(_controller.text);
  }

  void _onClear() {
    _controller.clear();
    widget.onChanged('');
    if (widget.onClear != null) {
      widget.onClear!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      style: AppTheme.bodyStyle,
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: AppTheme.inputHintStyle,
        prefixIcon:
            widget.prefixIcon ?? AppTheme.actionIcon(context, Icons.search),
        suffixIcon: _hasText
            ? IconButton(
                icon: AppTheme.actionIcon(context, Icons.clear),
                onPressed: _onClear,
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: AppTheme.mediumRadius,
        ),
        contentPadding: AppTheme.inputPadding,
      ),
      onChanged: widget.onChanged,
    );
  }
}
