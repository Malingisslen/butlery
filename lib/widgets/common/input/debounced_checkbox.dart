// lib/widgets/common/input/debounced_checkbox.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Checkbox with debounce functionality to prevent spam clicking
/// This widget wraps a standard checkbox and provides debouncing to prevent
/// multiple rapid state changes that could overwhelm the system.
class DebouncedCheckbox extends StatefulWidget {
  final bool value;
  final ValueChanged<bool?>? onChanged;
  final Color? activeColor;
  final Duration debounceDuration;

  const DebouncedCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.debounceDuration = AppDimensions.animationDurationCommon,
  });

  @override
  State<DebouncedCheckbox> createState() => _DebouncedCheckboxState();
}

class _DebouncedCheckboxState extends State<DebouncedCheckbox> {
  Timer? _debounceTimer;
  bool _currentValue = false;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
  }

  @override
  void didUpdateWidget(DebouncedCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _currentValue = widget.value;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _handleChanged(bool? newValue) {
    if (newValue == null || widget.onChanged == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _currentValue = newValue;
      });
    }

    // Cancel previous timer if it exists
    _debounceTimer?.cancel();

    // Set new timer
    _debounceTimer = Timer(widget.debounceDuration, () {
      widget.onChanged!(newValue);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: _currentValue,
      onChanged: _handleChanged,
      activeColor: widget.activeColor,
    );
  }
}
