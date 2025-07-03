// lib/widgets/realtime/edit_indicator.dart

import 'package:flutter/material.dart';

/// 🔍 AI INFO BLOCK:
/// Component: Edit Indicator - Shows who is currently editing what
/// File: widgets/realtime/edit_indicator.dart
/// Quick Guide: Visual feedback för real-time editing awareness - "X redigerar nu"
/// Dependencies IN: Ingen - bara UI state som props
/// Dependencies OUT: RealtimeMenuView, collaborative editing components
/// Data flow: Edit state → Props → Visual indicator med animation
/// State management: Stateless med animationer för smooth UX
/// Purpose: Real-time editing awareness - visa vem som redigerar vad
/// Common issues: Flicker vid rapid updates, overlapping indicators
/// Test coverage: 0% (ny komponent)
/// Performance: ⚡ Lightweight animations, minimal rebuilds
/// Analytics: Edit awareness usage, collaboration patterns
/// Code smells: ✅ Pure UI component för edit visualization
/// Connected to: RealtimeMenuView, collaborative editing flows
/// Used in phases: Fas 3 (UI Implementation) - Real-time edit awareness

/// Indikator för att visa vem som redigerar just nu
class EditIndicator extends StatefulWidget {
  final String editorName;
  final String? editorId;
  final String editingWhat;
  final Color? color;
  final bool isVisible;
  final Duration animationDuration;

  const EditIndicator({
    super.key,
    required this.editorName,
    this.editorId,
    required this.editingWhat,
    this.color,
    this.isVisible = true,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  State<EditIndicator> createState() => _EditIndicatorState();
}

class _EditIndicatorState extends State<EditIndicator>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    if (widget.isVisible) {
      _fadeController.forward();
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(EditIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _fadeController.forward();
        _pulseController.repeat(reverse: true);
      } else {
        _fadeController.reverse();
        _pulseController.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pulsing dot
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(width: 6),

                // Edit text
                Text(
                  '${widget.editorName} redigerar ${widget.editingWhat}',
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
}

/// Kompakt version för mindre utrymmen
class CompactEditIndicator extends StatelessWidget {
  final String editorName;
  final Color? color;
  final bool isVisible;

  const CompactEditIndicator({
    super.key,
    required this.editorName,
    this.color,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    final color = this.color ?? Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            editorName,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Overlay för edit indicators som kan visas över andra widgets
class EditIndicatorOverlay extends StatelessWidget {
  final List<EditIndicatorData> indicators;
  final Widget child;

  const EditIndicatorOverlay({
    super.key,
    required this.indicators,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,

        // Edit indicators positioned over content
        ...indicators.map((indicator) {
          return Positioned(
            top: indicator.position?.dy,
            left: indicator.position?.dx,
            child: EditIndicator(
              editorName: indicator.editorName,
              editorId: indicator.editorId,
              editingWhat: indicator.editingWhat,
              color: indicator.color,
              isVisible: indicator.isVisible,
            ),
          );
        }),
      ],
    );
  }
}

/// Data class för edit indicators
class EditIndicatorData {
  final String editorName;
  final String? editorId;
  final String editingWhat;
  final Color? color;
  final bool isVisible;
  final Offset? position;

  EditIndicatorData({
    required this.editorName,
    this.editorId,
    required this.editingWhat,
    this.color,
    this.isVisible = true,
    this.position,
  });

  EditIndicatorData copyWith({
    String? editorName,
    String? editorId,
    String? editingWhat,
    Color? color,
    bool? isVisible,
    Offset? position,
  }) {
    return EditIndicatorData(
      editorName: editorName ?? this.editorName,
      editorId: editorId ?? this.editorId,
      editingWhat: editingWhat ?? this.editingWhat,
      color: color ?? this.color,
      isVisible: isVisible ?? this.isVisible,
      position: position ?? this.position,
    );
  }
}

/// Helper för att skapa edit indicators från participant data
class EditIndicatorHelper {
  /// Få färg för användare baserat på deras ID
  static Color getColorForUser(String userId) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];

    final hash = userId.hashCode;
    return colors[hash.abs() % colors.length];
  }

  /// Skapa edit indicator för dag-redigering
  static EditIndicatorData forDayEdit({
    required String editorName,
    required String editorId,
    required String dayName,
    Offset? position,
  }) {
    return EditIndicatorData(
      editorName: editorName,
      editorId: editorId,
      editingWhat: dayName,
      color: getColorForUser(editorId),
      position: position,
    );
  }

  /// Skapa edit indicator för recept-redigering
  static EditIndicatorData forRecipeEdit({
    required String editorName,
    required String editorId,
    required String recipeName,
    Offset? position,
  }) {
    return EditIndicatorData(
      editorName: editorName,
      editorId: editorId,
      editingWhat: 'recept "$recipeName"',
      color: getColorForUser(editorId),
      position: position,
    );
  }

  /// Skapa edit indicator för meny-redigering
  static EditIndicatorData forMenuEdit({
    required String editorName,
    required String editorId,
    Offset? position,
  }) {
    return EditIndicatorData(
      editorName: editorName,
      editorId: editorId,
      editingWhat: 'menyn',
      color: getColorForUser(editorId),
      position: position,
    );
  }
}
