// Sub-widgets extracted from smart_import_view.dart to keep the parent under
// the 620-line baseline. Pure presentational — no logic changes.

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/smart_import_viewmodel.dart';
import 'package:butlery/widgets/common/feedback/inline_error.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

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
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingMd),
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
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
          const SizedBox(height: AppDimensions.spacingSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onDismiss,
                child: Text(context.l10n.importPendingDismiss),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              FilledButton(
                onPressed: onRetry,
                child: Text(context.l10n.importPendingRetry),
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
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      enabled: !viewModel.isImporting,
      maxLines: 5,
      minLines: 3,
      decoration: InputDecoration(
        hintText: context.l10n.importPasteLinkOrText,
        // The hint is text.secondary itself, never faded, and the field's
        // borders come from the input theme: focus is never a thicker ink
        // border, which vanished on dark (enhet-4 import_widgets.dart:101;
        // tokens.json:40-53, :155-160).
        hintStyle: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.all(AppDimensions.spacingMd),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  controller.clear();
                  viewModel.clearInput();
                },
                tooltip: context.l10n.commonClear,
              )
            : null,
      ),
      textCapitalization: TextCapitalization.none,
      keyboardType: TextInputType.multiline,
    );
  }
}

/// P5-U06: a failed import, in three parts (content-style-guide.md:87-97).
///
/// The error line says what happened and what was kept ([InlineError], the
/// drawn error boundary, Komponentark v1:755-758). Under it, "Andra vägar
/// till samma recept" draws the [routes] the failure carries: a failure is a
/// fork, not a dead end (produktregler.md:557; Skarmar v12 etapp 4 import
/// #impinget). The first route is the filled button and the rest are
/// outlined, full width and 48 dp high, as drawn.
///
/// Colours, both modes, from the theme: the heading is
/// colorScheme.onSurfaceVariant = text.secondary, #627061 light and #93A48D
/// dark (tokens.json:62-65). The drawing's dark heading is #C9D3C4
/// (text.bodyMuted); text.secondary is the role the light value names, and
/// it clears 4.5:1 on the dark surface. The first route takes the app's
/// filled button theme. The outlined routes are drawn with --text-kontroll-a
/// and a 1.5 px --ram-kontroll-a outline (Skarmar v12 etapp 4 import:27-28):
/// #24382C text and outline in light (colorScheme.primary); in dark a paper
/// outline at 40 % (overlay.paperWash, tokens.json:263) and text in
/// colorScheme.onSurface (#F5F4ED, text.primary). The drawn dark text is
/// #C9D3C4 (text.bodyMuted, tokens.json:174-177), which no generated member
/// carries yet; the app theme's own outlined foreground (primary) would sit
/// at 1.3:1 on the dark surface.
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
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InlineError(what: message, preserved: preserved),
        if (routes.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.spacingMd),
          Semantics(
            header: true,
            child: Text(
              l10n.importFailureOtherRoutes.toUpperCase(),
              style: AppTextStyles.overline.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          for (final (i, route) in routes.indexed) ...[
            if (i > 0) const SizedBox(height: AppDimensions.spacingSm),
            _RouteButton(
              key: routeKey(route),
              filled: i == 0,
              icon: switch (route) {
                ImportRoute.photo => Icons.photo_camera_outlined,
                ImportRoute.pasteText => Icons.content_paste,
                ImportRoute.manual => Icons.edit_outlined,
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
    // Skarmar v12 etapp 4 #impinget: min-height 48, radius 8 (radius.control).
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size.fromHeight(AppDimensions.minTouchTarget),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
        ),
      ),
    );
    final iconWidget = Icon(icon, size: AppDimensions.iconSize18);
    final cs = Theme.of(context).colorScheme;
    final dark = cs.brightness == Brightness.dark;
    final outlinedStyle = style.copyWith(
      foregroundColor: WidgetStatePropertyAll(
        dark ? cs.onSurface : cs.primary,
      ),
      iconColor: WidgetStatePropertyAll(dark ? cs.onSurface : cs.primary),
      side: WidgetStatePropertyAll(
        BorderSide(
          color: dark ? AppModeColors.paperWash(cs.brightness) : cs.primary,
          width: 1.5,
        ),
      ),
    );
    return filled
        ? FilledButton.icon(
            onPressed: onPressed,
            style: style,
            icon: iconWidget,
            label: Text(label),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            style: outlinedStyle,
            icon: iconWidget,
            label: Text(label),
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
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Paste button (shown when input is empty)
        if (viewModel.input.isEmpty) ...[
          OutlinedButton.icon(
            onPressed: onPaste,
            icon: const Icon(Icons.content_paste),
            label: Text(context.l10n.importPasteFromClipboard),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimensions.spacingModerate,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingL),
        ],

        // Import button.
        // BUT-403: `btn-import-url` identifier for browser a11y tree.
        Semantics(
          identifier: 'btn-import-url',
          button: true,
          enabled: viewModel.canImport && !viewModel.isImporting,
          label: context.l10n.importImport,
          // Busy keeps the button's shape and name, with the plate line
          // along its bottom edge and "Hämtar receptet …" (Komponentark
          // v1:365, :372; content-style-guide.md:63). Never a spinner.
          child: BusyButtonSemantics(
            busy: viewModel.isImporting,
            name: context.l10n.importImport,
            busyLabel: context.l10n.importFetchingRecipe,
            child: FilledButton.icon(
              key: const ValueKey('test-smart-import-url'),
              onPressed: viewModel.isImporting
                  ? PlateLineButton.ignore
                  : (viewModel.canImport ? onImport : null),
              icon: viewModel.isImporting
                  ? const SizedBox.shrink()
                  : const Icon(Icons.download),
              label: Text(
                viewModel.isImporting
                    ? context.l10n.importFetchingRecipe
                    : context.l10n.importImport,
              ),
              style: viewModel.isImporting
                  ? PlateLineButton.busyStyle(
                      FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      theme.filledButtonTheme.style,
                    )
                  : FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
            ),
          ),
        ),

        const SizedBox(height: AppDimensions.spacingSm),

        // Manual import link
        TextButton(
          onPressed: viewModel.canImport && !viewModel.isImporting
              ? onManualImport
              : null,
          child: Text(context.l10n.importManually),
        ),
      ],
    );
  }
}
