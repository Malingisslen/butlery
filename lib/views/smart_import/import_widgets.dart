// Sub-widgets extracted from smart_import_view.dart to keep the parent under
// the 620-line baseline. Pure presentational — no logic changes.

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/viewmodels/smart_import_viewmodel.dart';
import 'package:butlery/widgets/common/feedback/inline_error.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/section_heading.dart';
import 'package:butlery/widgets/common/input/styled_input.dart';

/// Banner shown when a previous import is pending retry.
class PendingImportBanner extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  const PendingImportBanner({
    super.key,
    required this.onRetry,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppDimensions.space16),
      padding: const EdgeInsets.all(AppDimensions.space16),
      color: cs.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.importPendingRetryPrompt,
            style: AppTextStyles.bodyMedium.copyWith(
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: AppDimensions.space8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ButleryTextButton(
                label: context.l10n.importPendingDismiss,
                onPressed: onDismiss,
              ),
              const SizedBox(width: AppDimensions.space8),
              ActionButtons.primaryButton(
                context,
                label: context.l10n.importPendingRetry,
                onPressed: onRetry,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Text input section with clear button.
class ImportInputSection extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final SmartImportViewModel viewModel;
  final ValueChanged<String> onChanged;

  const ImportInputSection({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.viewModel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StyledInput(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      enabled: !viewModel.isImporting,
      maxLines: 5,
      minLines: 3,
      hint: context.l10n.importPasteLinkOrText,
      keyboardType: TextInputType.multiline,
      suffixIcon: controller.text.isNotEmpty
          ? AppIconButton(
              icon: ButleryIcons.x,
              semanticLabel: context.l10n.commonClear,
              onPressed: () {
                controller.clear();
                viewModel.clearInput();
              },
            )
          : null,
    );
  }
}

/// P5-U06: a failed import, in three parts (content-style-guide.md:87-97).
///
/// The error line says what happened and what was kept ([InlineError], the
/// drawn error boundary, Komponentark v1:755-758). Under it, "Andra vägar
/// till samma recept" draws the [routes] the failure carries: a failure is a
/// fork, not a dead end (produktregler.md:557; Skarmar v12 etapp 4 import
/// #impinget).
///
/// Colours, both modes, from the theme: the heading is
/// colorScheme.onSurfaceVariant = text.secondary, #5B6959 light and #A9B2A0
/// dark (tokens.json:62-65). The drawing's dark heading is #C9D3C4
/// (text.bodyMuted). The first route takes the app's
/// filled button theme. The outlined routes are drawn with --text-kontroll-a
/// and a 1.5 px --ram-kontroll-a outline (Skarmar v12 etapp 4 import:27-28):
/// #24382C text and outline in light (colorScheme.onSurface, equal to ink there); in dark a paper
/// outline at 40 % (overlay.paperWash, tokens.json:263) and text in
/// colorScheme.onSurface (#F5F4ED, text.primary). The drawn dark text is
/// #C9D3C4 (text.bodyMuted); the app theme's own
/// outlined foreground (primary) would sit at 1.3:1 on the dark surface.
class ImportErrorMessage extends StatelessWidget {
  final String message;
  final String? preserved;
  final List<ImportRoute> routes;
  final void Function(ImportRoute route) onRoute;

  const ImportErrorMessage({
    super.key,
    required this.message,
    required this.routes,
    required this.onRoute,
    this.preserved,
  });

  /// A route's button. The key is for tests, not identity.
  static Key routeKey(ImportRoute route) =>
      ValueKey<String>('importError.route.${route.name}');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InlineError(what: message, preserved: preserved),
        if (routes.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.space16),
          SectionHeading(l10n.importFailureOtherRoutes),
          const SizedBox(height: AppDimensions.space8),
          for (final (i, route) in routes.indexed) ...[
            if (i > 0) const SizedBox(height: AppDimensions.space8),
            _RouteButton(
              key: routeKey(route),
              filled: i == 0,
              icon: switch (route) {
                ImportRoute.photo => ButleryIcons.camera,
                ImportRoute.pasteText => ButleryIcons.clipboard,
                ImportRoute.manual => ButleryIcons.pencil,
              },
              label: switch (route) {
                ImportRoute.photo => l10n.importRoutePhoto,
                ImportRoute.pasteText => l10n.importRoutePasteText,
                ImportRoute.manual => l10n.importAddManually,
              },
              onPressed: () => onRoute(route),
            ),
          ],
        ],
      ],
    );
  }
}

class _RouteButton extends StatelessWidget {
  const _RouteButton({
    required this.filled,
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final bool filled;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return filled
        ? ActionButtons.primaryButton(
            context,
            onPressed: onPressed,
            icon: icon,
            label: label,
            isExpanded: true,
          )
        : ActionButtons.outlinedButton(
            context,
            onPressed: onPressed,
            icon: icon,
            label: label,
            isExpanded: true,
          );
  }
}

/// Import / paste / manual-import action buttons.
class ImportActionSection extends StatelessWidget {
  final SmartImportViewModel viewModel;
  final VoidCallback onImport;
  final VoidCallback onManualImport;
  final VoidCallback onPaste;

  const ImportActionSection({
    super.key,
    required this.viewModel,
    required this.onImport,
    required this.onManualImport,
    required this.onPaste,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Paste button (shown when input is empty)
        if (viewModel.input.isEmpty) ...[
          ActionButtons.outlinedButton(
            context,
            onPressed: onPaste,
            icon: ButleryIcons.clipboard,
            label: context.l10n.importPasteFromClipboard,
            isExpanded: true,
          ),
          const SizedBox(height: AppDimensions.space12),
        ],

        // Import button.
        // BUT-403: `btn-import-url` identifier for browser a11y tree.
        Semantics(
          identifier: 'btn-import-url',
          button: true,
          enabled: viewModel.canImport && !viewModel.isImporting,
          label: context.l10n.importImport,
          child: ActionButtons.primaryButton(
            context,
            key: const ValueKey('test-smart-import-url'),
            onPressed: viewModel.canImport ? onImport : null,
            icon: ButleryIcons.download,
            label: context.l10n.importImport,
            isLoading: viewModel.isImporting,
            loadingText: context.l10n.importFetchingRecipe,
            isExpanded: true,
          ),
        ),

        const SizedBox(height: AppDimensions.space8),

        // Manual import link
        ButleryTextButton(
          label: context.l10n.importManually,
          onPressed: viewModel.canImport && !viewModel.isImporting
              ? onManualImport
              : null,
        ),
      ],
    );
  }
}
