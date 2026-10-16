/// Text import view for parsing recipes from social media and copied text.

// lib/views/fran_sociala_medier_view.dart

import 'package:butlery/core/router/manual_entry_route.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/text_import_viewmodel.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/import/batch_import_preview.dart';
import 'package:butlery/widgets/common/utility_components.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/source_url_display.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/layout/tinted_note.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/parsing/recipe_text_heuristic.dart';
import 'package:butlery/services/persistence/auto_save_manager.dart';
import 'package:butlery/services/tagging/allergen_mismatch.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/widgets/guest/guest_import_limit_listener.dart';
import 'package:butlery/widgets/import/allergen_setup_banner.dart';
import 'package:butlery/widgets/import/confidence_indicator.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/input/styled_input.dart';

/// Text import view for parsing recipes from copied text.
class FranSocialaMedierView extends StatefulWidget {
  final String? initialText;

  /// BUT-928: overall OCR confidence (0.0-1.0) when [initialText] came from
  /// the photo-import OCR step — re-surfaces the preview badge here so the
  /// quality signal isn't dropped at the handoff. Null for non-OCR entry.
  final double? ocrConfidence;

  /// True when the photo import hands its OCR text over: the guest's
  /// import count already holds that import (BUT-920).
  final bool continuesImport;

  const FranSocialaMedierView({
    super.key,
    this.initialText,
    this.ocrConfidence,
    this.continuesImport = false,
  });

  /// Shared text arrives as a String; the photo import hands over its OCR
  /// text and confidence.
  factory FranSocialaMedierView.fromRouteArguments(Object? arguments) {
    if (arguments is Map<String, dynamic>) {
      return FranSocialaMedierView(
        initialText: arguments['text'] as String?,
        // BUT-928: overall OCR confidence from the photo-import preview.
        ocrConfidence: arguments['ocrConfidence'] as double?,
        continuesImport: true,
      );
    }
    return FranSocialaMedierView(
      initialText: arguments is String ? arguments : null,
    );
  }

  @override
  State<FranSocialaMedierView> createState() => _FranSocialaMedierViewState();
}

class _FranSocialaMedierViewState extends State<FranSocialaMedierView> {
  late final TextImportViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ServiceLocator.get<TextImportViewModel>();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      // A pasted link reaches the AI structuring, which a guest's import
      // count covers; pasted text alone is parsed on the device.
      child: GuestImportLimitListener(
        startsImport: !widget.continuesImport,
        child: _FranSocialaMedierViewContent(
          initialText: widget.initialText,
          ocrConfidence: widget.ocrConfidence,
        ),
      ),
    );
  }
}

class _FranSocialaMedierViewContent extends StatefulWidget {
  final String? initialText;
  final double? ocrConfidence;

  const _FranSocialaMedierViewContent({
    this.initialText,
    this.ocrConfidence,
  });

  @override
  State<_FranSocialaMedierViewContent> createState() =>
      _FranSocialaMedierViewContentState();
}

class _FranSocialaMedierViewContentState
    extends State<_FranSocialaMedierViewContent> {
  /// BUT-915: single global key — text-import is a CREATE flow with
  /// one-at-a-time user intent. Unlike per-recipe comment drafts, there's
  /// no multi-instance isolation concern. BUT-904: persistence is now the
  /// shared AutoSaveManager.
  final AutoSaveManager<String> _draftManager = AutoSaveManager<String>(
    storageKey: 'text_import_draft_v1',
    encode: (text) => text,
    decode: (raw) => raw,
    logLabel: 'FranSocialaMedierView',
  );

  late TextEditingController _textController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();

    _textController = TextEditingController(text: widget.initialText.orEmpty());

    // Update ViewModel with initial text after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.initialText != null && widget.initialText!.isNotEmpty) {
        // initialText (e.g. from URL-import sharing) wins over persisted
        // draft — user is starting from fresh content.
        final viewModel = context.read<TextImportViewModel>();
        viewModel.updateInputText(widget.initialText!);
        viewModel.parseText();
      } else {
        await _loadDraft();
      }
      _isInitialized = true;
    });
  }

  Future<void> _loadDraft() async {
    final saved = await _draftManager.load();
    if (saved != null && saved.isNotEmpty && mounted) {
      _textController.text = saved;
      context.read<TextImportViewModel>().updateInputText(saved);
    }
  }

  void _onTextChanged(String text, TextImportViewModel viewModel) {
    viewModel.updateInputText(text);
    // Eager save — pasted recipes are larger than comments, but write
    // volume is still bounded (one save per keystroke; SharedPreferences
    // is isolate-fenced so it doesn't block input latency).
    _draftManager.save(text);
  }

  @override
  void dispose() {
    _draftManager.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _parseAndNavigate(BuildContext context) async {
    final viewModel = context.read<TextImportViewModel>();

    // BUT-1037: cheap recipe-likeness gate. The user can always override,
    // so edge-case recipes are never blocked.
    if (!RecipeTextHeuristic.looksLikeRecipe(viewModel.inputText)) {
      final proceed = await _confirmNonRecipeImport(context);
      if (!proceed) {
        ServiceLocator.tryGet<AnalyticsService>()?.import
            .logWarnDialogCancelled(source: 'text_paste');
        return;
      }
      if (!context.mounted) return;
    }

    final success = await viewModel.parseText();

    if (success && context.mounted && viewModel.hasMultipleParsedRecipes) {
      // BUT-1040: a cookbook-style paste produced several recipes — drop the
      // draft and hand off to the shared multi-recipe picker (same widget the
      // photo and file import flows use) so the user ticks which to keep.
      await _draftManager.clear();
      if (!context.mounted) return;
      await _pickAndSaveMultiple(context, viewModel);
      return;
    }

    if (success && context.mounted) {
      // User explicitly moved past the input stage — drop the draft so the
      // next visit to this surface starts blank.
      await _draftManager.clear();
      if (!context.mounted) return;
      // BUT-1208: non-blocking allergen-setup prompt when the parsed recipe
      // CONTAINS an allergen the user hasn't configured. Covers both direct
      // text/paste import and the single-photo handoff that lands here.
      // parsedRecipe carries the Phase-1 tags ImportManager attached — no new
      // LLM/network — and the app-level ScaffoldMessenger survives the push.
      // Mirrors SmartImportView._navigateToRecipeEditor.
      final parsed = viewModel.parsedRecipe;
      if (parsed != null) {
        final prefs = ServiceLocator.get<UserService>().allergenPreferences;
        if (AllergenMismatch.unconfiguredContainedAllergens(
          parsed,
          prefs,
        ).isNotEmpty) {
          AllergenSetupBanner.show(context);
        }
      }
      // BUT-900 follow-on: match the smart-import path — replace this text-import
      // form with the recipe form (named route) so saving lands on the new
      // recipe with a clean back-stack, instead of leaving a dead, used-up
      // import form behind.
      Navigator.pushReplacementNamed(
        context,
        Routes.manualEntry,
        arguments: {
          'initialRecipe': viewModel.parsedRecipe,
          'isTemplate': true,
          ManualEntryRoute.importedWithoutIngredientsKey:
              parsed != null && ManualEntryRoute.hasNoIngredients(parsed),
        },
      );
    } else if (context.mounted && viewModel.hasError) {
      SnackBarUtils.showFailure(context, what: viewModel.error!);
    }
  }

  /// BUT-1040: multi-recipe handoff — let the user tick which parsed recipes
  /// to add via the shared [BatchImportPreview] picker (same pattern as the
  /// photo and file import flows), then save the selection.
  Future<void> _pickAndSaveMultiple(
    BuildContext context,
    TextImportViewModel viewModel,
  ) async {
    final selected = await Navigator.push<List<Recipe>>(
      context,
      MaterialPageRoute(
        builder: (_) => BatchImportPreview(
          recipes: viewModel.parsedRecipes,
          backTo: context.l10n.importFromSocialMedia,
        ),
      ),
    );
    if (!context.mounted || selected == null || selected.isEmpty) return;

    final ok = await viewModel.saveSelectedRecipes(selected);
    if (!context.mounted) return;

    if (ok) {
      // One allergen-setup prompt covers the whole batch (mirrors
      // PhotoImportView._navigateToMultiRecipePicker) — reuses the Phase-1 tags
      // ImportManager attached during parse, no new LLM/network.
      final prefs = ServiceLocator.get<UserService>().allergenPreferences;
      if (AllergenMismatch.anyUnconfigured(selected, prefs)) {
        AllergenSetupBanner.show(context);
      }
      SnackBarUtils.showSuccess(
        context,
        context.l10n.importComplete(selected.length, 0),
      );
      // BUT-900 follow-on: land on the recipe list so the user sees the batch
      // they just imported, instead of bouncing back to the stale import form.
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.home,
          (route) => false,
        );
      }
    } else if (viewModel.hasError) {
      SnackBarUtils.showFailure(context, what: viewModel.error!);
    }
  }

  /// BUT-1037: non-blocking confirm shown when the pasted text fails the
  /// recipe-likeness heuristic. Returns true if the user chooses to import
  /// anyway, false to back out.
  Future<bool> _confirmNonRecipeImport(BuildContext context) async {
    final result = await showButleryDialog<bool>(
      context: context,
      builder: (dialogContext) => ButleryDialog.confirm(
        title: dialogContext.l10n.importNotRecipeTitle,
        message: dialogContext.l10n.importNotRecipeBody,
        primaryLabel: dialogContext.l10n.importNotRecipeConfirm,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TextImportViewModel>();

    return ButleryPage.undersida(
      title: context.l10n.importFromSocialMedia,
      showTabBar: false,
      body: SingleChildScrollView(
        padding: AppDimensions.responsiveContentPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Show if recipe comes from URL
            if (viewModel.sourceUrl != null) ...[
              SourceUrlDisplay(sourceUrl: viewModel.sourceUrl!),
              const SizedBox(height: AppDimensions.space8),
            ],

            // BUT-928: same green/orange/red badge as the photo-import
            // preview step — describes the OCR pass that produced the
            // initial text (kept visible even if the user edits).
            if (widget.ocrConfidence != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: ConfidenceIndicator(
                  confidence: widget.ocrConfidence!,
                ),
              ),
              const SizedBox(height: AppDimensions.space8),
            ],

            _buildTextInput(context, viewModel),
            const SizedBox(height: AppDimensions.space8),
            Text(
              context.l10n.importPasteHelp,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimensions.space16),
            _buildCaptionWarning(context),
            const SizedBox(height: AppDimensions.space16),

            UtilityComponents.primaryButton(
              context,
              label: context.l10n.importFetchRecipe,
              icon: ButleryIcons.zap,
              onPressed: viewModel.isParsing || !viewModel.canParse
                  ? null
                  : () => _parseAndNavigate(context),
              isLoading: viewModel.isParsing,
              loadingText: context.l10n.importParsingText,
              isExpanded: true,
            ),

            // Error message
            if (viewModel.hasError) ...[
              const SizedBox(height: AppDimensions.space8),
              StateWidget.error(
                message: viewModel.error!,
                preserved: context.l10n.errorPreservedLink,
              ),
            ],
            const SizedBox(height: AppDimensions.space16),
            TintedNote(
              child: Text(
                context.l10n.importVideoNotRead,
                style: TintedNote.textStyle(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptionWarning(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = TintedNote.textStyle(context);
    return TintedNote(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ButleryIcon(
            ButleryIcons.triangleAlert,
            size: AppDimensions.iconSizeM,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(width: AppDimensions.space12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: style,
                text: context.l10n.importCaptionWarningLead,
                children: [
                  TextSpan(
                    text: context.l10n.importCaptionWarningEmphasis,
                    style: style.merge(AppTextStyles.bodySmallBold),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextInput(BuildContext context, TextImportViewModel viewModel) {
    // Synchronize ViewModel text with controller if they differ
    if (_isInitialized && _textController.text != viewModel.inputText) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_textController.text != viewModel.inputText) {
          _textController.text = viewModel.inputText;
        }
      });
    }

    return StyledInput(
      label: context.l10n.importLinkOrCaptionLabel,
      controller: _textController,
      onChanged: (text) => _onTextChanged(text, viewModel),
      hint: context.l10n.importPasteRecipeHint,
      keyboardType: TextInputType.multiline,
      minLines: 8,
      maxLines: 14,
      // A limit without the counter line under the field.
      inputFormatters: [LengthLimitingTextInputFormatter(10000)],
    );
  }
}
