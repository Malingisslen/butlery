// lib/widgets/realtime/realtime_status_indicator.dart

import 'package:flutter/material.dart';

/// 🔍 AI INFO BLOCK:
/// Component: Realtime Status Indicator - Connection status display
/// File: widgets/realtime/realtime_status_indicator.dart
/// Quick Guide: Compact widget som visar online/offline status med emoji och tooltip
/// Dependencies IN: Ingen - bara UI state som props
/// Dependencies OUT: RealtimeMenuView, andra realtime views
/// Data flow: Connection status → Props → Visual indicator
/// State management: Stateless - tar emot status som props
/// Purpose: User awareness av connection status med subtle visual feedback
/// Common issues: Status flapping, unclear indicators
/// Test coverage: 0% (ny komponent)
/// Performance: ⚡ Stateless, minimal overhead
/// Analytics: Connection status visibility patterns
/// Code smells: ✅ Pure UI component - ingen business logic
/// Connected to: ConnectionMonitor, RealtimeMenuView
/// Used in phases: Fas 3 (UI Implementation) - Connection awareness widget

class RealtimeStatusIndicator extends StatelessWidget {
  final bool isOnline;
  final String statusDescription;
  final String statusEmoji;
  final bool showText;
  final EdgeInsets padding;

  const RealtimeStatusIndicator({
    super.key,
    required this.isOnline,
    required this.statusDescription,
    required this.statusEmoji,
    this.showText = false,
    this.padding = const EdgeInsets.all(8),
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: statusDescription,
      child: Container(
        padding: padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated emoji/icon
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                statusEmoji,
                key: ValueKey(statusEmoji),
                style: const TextStyle(fontSize: 16),
              ),
            ),

            // Optional text
            if (showText) ...[
              const SizedBox(width: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  statusDescription,
                  key: ValueKey(statusDescription),
                  style: TextStyle(
                    fontSize: 12,
                    color: isOnline
                        ? Theme.of(context).colorScheme.onSurface
                        : Colors.red,
                    fontWeight: isOnline ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Expanded status indicator för större visningar
class RealtimeStatusBanner extends StatelessWidget {
  final bool isOnline;
  final String statusDescription;
  final String statusEmoji;
  final VoidCallback? onRetry;

  const RealtimeStatusBanner({
    super.key,
    required this.isOnline,
    required this.statusDescription,
    required this.statusEmoji,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isOnline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.red.withValues(alpha: 0.1),
      child: Row(
        children: [
          Text(
            statusEmoji,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Offline',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                Text(
                  statusDescription,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('Försök igen'),
            ),
        ],
      ),
    );
  }
}
