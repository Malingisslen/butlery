// lib/widgets/common/input/debounced_button.dart

import 'dart:async';
import 'package:flutter/material.dart';

/// A button wrapper that prevents rapid successive taps through debouncing.
/// Useful for preventing double-submits on forms and duplicate API calls.
///
/// Features:
/// - Configurable debounce duration
/// - Optional loading indicator during debounce
/// - Supports any child widget (use with ElevatedButton, TextButton, etc.)
/// - Can disable button during async operations
///
/// Example usage:
/// ```dart
/// DebouncedButton(
///   onPressed: () async {
///     await saveData();
///   },
///   child: ElevatedButton(
///     onPressed: null, // Parent handles the press
///     child: Text('Save'),
///   ),
/// )
/// ```
class DebouncedButton extends StatefulWidget {
  /// The callback to execute after debounce period.
  /// If this returns a Future, the button stays disabled until it completes.
  final FutureOr<void> Function()? onPressed;

  /// The child widget (typically a button).
  final Widget child;

  /// Duration to wait before allowing another press.
  final Duration debounceDuration;

  /// Whether to show a loading indicator during async operations.
  final bool showLoadingIndicator;

  /// Custom loading indicator widget.
  final Widget? loadingIndicator;

  /// Whether the button is currently disabled (external control).
  final bool disabled;

  const DebouncedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.debounceDuration = const Duration(milliseconds: 500),
    this.showLoadingIndicator = false,
    this.loadingIndicator,
    this.disabled = false,
  });

  @override
  State<DebouncedButton> createState() => _DebouncedButtonState();
}

class _DebouncedButtonState extends State<DebouncedButton> {
  bool _isDebouncing = false;
  bool _isProcessing = false;
  Timer? _debounceTimer;

  bool get _canPress =>
      !_isDebouncing &&
      !_isProcessing &&
      !widget.disabled &&
      widget.onPressed != null;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _handlePressed() async {
    if (!_canPress) return;

    // Start debounce period
    if (mounted) {
      setState(() {
        _isDebouncing = true;
        _isProcessing = true;
      });
    }

    try {
      // Execute the callback
      final result = widget.onPressed!();
      if (result is Future) {
        await result;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }

    // Set debounce timer to prevent rapid re-clicks
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounceDuration, () {
      if (mounted) {
        setState(() {
          _isDebouncing = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showLoadingIndicator && _isProcessing) {
      return widget.loadingIndicator ??
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
    }

    return GestureDetector(
      onTap: _canPress ? _handlePressed : null,
      behavior: HitTestBehavior.opaque,
      child: IgnorePointer(
        ignoring: !_canPress,
        child: Opacity(
          opacity: _canPress ? 1.0 : 0.6,
          child: widget.child,
        ),
      ),
    );
  }
}

/// A simple wrapper for ElevatedButton with debounce built-in.
/// Provides a more ergonomic API for common button debouncing.
class DebouncedElevatedButton extends StatelessWidget {
  final FutureOr<void> Function()? onPressed;
  final Widget child;
  final Duration debounceDuration;
  final ButtonStyle? style;

  const DebouncedElevatedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.debounceDuration = const Duration(milliseconds: 500),
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return _DebouncedMaterialButton(
      onPressed: onPressed,
      debounceDuration: debounceDuration,
      builder: (context, onTap, isEnabled) => ElevatedButton(
        onPressed: isEnabled ? onTap : null,
        style: style,
        child: child,
      ),
    );
  }
}

/// A simple wrapper for TextButton with debounce built-in.
class DebouncedTextButton extends StatelessWidget {
  final FutureOr<void> Function()? onPressed;
  final Widget child;
  final Duration debounceDuration;
  final ButtonStyle? style;

  const DebouncedTextButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.debounceDuration = const Duration(milliseconds: 500),
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return _DebouncedMaterialButton(
      onPressed: onPressed,
      debounceDuration: debounceDuration,
      builder: (context, onTap, isEnabled) => TextButton(
        onPressed: isEnabled ? onTap : null,
        style: style,
        child: child,
      ),
    );
  }
}

/// Internal helper for Material buttons with debounce.
class _DebouncedMaterialButton extends StatefulWidget {
  final FutureOr<void> Function()? onPressed;
  final Duration debounceDuration;
  final Widget Function(BuildContext, VoidCallback?, bool) builder;

  const _DebouncedMaterialButton({
    required this.onPressed,
    required this.debounceDuration,
    required this.builder,
  });

  @override
  State<_DebouncedMaterialButton> createState() =>
      _DebouncedMaterialButtonState();
}

class _DebouncedMaterialButtonState extends State<_DebouncedMaterialButton> {
  bool _isDebouncing = false;
  bool _isProcessing = false;
  Timer? _debounceTimer;

  bool get _canPress =>
      !_isDebouncing && !_isProcessing && widget.onPressed != null;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _handlePressed() async {
    if (!_canPress) return;

    if (mounted) {
      setState(() {
        _isDebouncing = true;
        _isProcessing = true;
      });
    }

    try {
      final result = widget.onPressed!();
      if (result is Future) {
        await result;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounceDuration, () {
      if (mounted) {
        setState(() {
          _isDebouncing = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      _canPress ? _handlePressed : null,
      _canPress,
    );
  }
}
