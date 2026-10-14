// lib/widgets/common/state/butlery_section_state.dart
//
// The state of one section of a page: loading, empty or failed. StateWidget
// fills a whole view; this is the same three states drawn at the size of a
// section, with the rest of the page standing. A view names the state and
// its words; it never builds its own error or empty class.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/feedback/inline_error.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/state_widget.dart';

enum _SectionStateKind { loading, empty, error }

class ButlerySectionState extends StatelessWidget {
  /// The section is being fetched. [message] says what: "Hämtar veckomenyn …".
  const ButlerySectionState.loading({required String this.message, super.key})
    : _kind = _SectionStateKind.loading,
      preserved = null,
      actionLabel = null,
      onAction = null,
      secondaryLabel = null,
      onSecondary = null;

  /// The section has nothing to show. [actionLabel] and [onAction] offer the
  /// way to fill it.
  const ButlerySectionState.empty({
    required String this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  }) : _kind = _SectionStateKind.empty,
       preserved = null,
       secondaryLabel = null,
       onSecondary = null;

  /// The section could not be read: what happened, what was kept, and the
  /// action. A second action (such as "Visa sparad plan") stands after the
  /// first.
  const ButlerySectionState.error({
    required String this.message,
    this.preserved,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    super.key,
  }) : _kind = _SectionStateKind.error;

  final _SectionStateKind _kind;
  final String? message;
  final String? preserved;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// The retry. The key is for tests, not identity.
  static const Key actionKey = ValueKey<String>('sectionState.action');

  /// The second action. The key is for tests, not identity.
  static const Key secondaryKey = ValueKey<String>('sectionState.secondary');

  @override
  Widget build(BuildContext context) {
    return switch (_kind) {
      _SectionStateKind.loading => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.space16),
        child: StateWidget.loading(message: message!),
      ),
      _SectionStateKind.empty => _empty(context),
      _SectionStateKind.error => _error(context),
    };
  }

  Widget _empty(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message!,
            style: AppTextStyles.bodyMedium.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          if (actionLabel != null && onAction != null)
            ButleryTextButton(
              key: actionKey,
              label: actionLabel!,
              onPressed: onAction,
            ),
        ],
      ),
    );
  }

  Widget _error(BuildContext context) {
    final hasAction = actionLabel != null && onAction != null;
    final hasSecondary = secondaryLabel != null && onSecondary != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        InlineError(what: message!, preserved: preserved),
        if (hasAction || hasSecondary) ...[
          const SizedBox(height: AppDimensions.space8),
          // A Wrap, so 200 % text stacks the two.
          Wrap(
            spacing: AppDimensions.space8,
            runSpacing: AppDimensions.space8,
            children: [
              if (hasAction)
                ActionButtons.outlinedButton(
                  context,
                  key: actionKey,
                  label: actionLabel!,
                  icon: ButleryIcons.refreshCw,
                  onPressed: onAction,
                ),
              if (hasSecondary)
                ButleryTextButton(
                  key: secondaryKey,
                  label: secondaryLabel!,
                  tone: ButleryTextButtonTone.link,
                  onPressed: onSecondary,
                ),
            ],
          ),
        ],
      ],
    );
  }
}
