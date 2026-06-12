/// Text import view for parsing recipes from social media and copied text.

// lib/views/fran_sociala_medier_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/viewmodels/text_import_viewmodel.dart';
import 'package:butlery/views/skriv_sjalv_recept_view.dart';
import 'package:butlery/widgets/common/utility_components.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/source_url_display.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/parsing/recipe_text_heuristic.dart';
import 'package:butlery/services/persistence/auto_save_manager.dart';
import 'package:butlery/services/tagging/allergen_mismatch.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/widgets/import/allergen_setup_banner.dart';
import 'package:butlery/widgets/import/confidence_indicator.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Text import view for parsing recipes from copied text.
class FranSocialaMedierView extends StatefulWidget {
  final String? initialText;
  final String? sourceUrl;

  /// BUT-928: overall OCR confidence (0.0-1.0) when [initialText] came from
  /// the photo-import OCR step — re-surfaces the preview badge here so the
  /// quality signal isn't dropped at the handoff. Null for non-OCR entry.
  final double? ocrConfidence;

  const FranSocialaMedierView({
    super.key,
    this.initialText,
    this.sourceUrl,
    this.ocrConfidence,
  });

  @override
  State<FranSocialaMedierView> createState() => _FranSocialaMedierViewState();
}

class _FranSocialaMedierViewState extends State<FranSocialaMedierView> {
  late final TextImportViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ServiceLocator.get<TextImportViewModel>();
    if (widget.sourceUrl != null) {
      _viewModel.setSourceUrl(widget.sourceUrl!);
    }
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
      child: _FranSocialaMedierViewContent(
        initialText: widget.initialText,
        sourceUrl: widget.sourceUrl,
        ocrConfidence: widget.ocrConfidence,
      ),
    );
  }
}

class _FranSocialaMedierViewContent extends StatefulWidget {
  final String? initialText;
  final String? sourceUrl;
  final double? ocrConfidence;

  const _FranSocialaMedierViewContent({
    this.initialText,
    this.sourceUrl,
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

    // BUT-1037: cheap recipe-likeness gate — warn before spending a paid LLM
    // parse on text that clearly isn't a recipe. The user can always override,
    // so edge-case recipes are never blocked.
    if (!RecipeTextHeuristic.looksLikeRecipe(viewModel.inputText)) {
      final proceed = await _confirmNonRecipeImport(context);
      if (!proceed) {
        ServiceLocator.tryGet<AnalyticsService>()
            ?.import
            .logWarnDialogCancelled(source: 'text_paste');
        return;
      }
      if (!context.mounted) return;
    }

    final success = await viewModel.parseText();

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
        if (AllergenMismatch.unconfiguredContainedAllergens(parsed, prefs)
            .isNotEmpty) {
          AllergenSetupBanner.show(context);
        }
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SkrivSjalvReceptView(
            initialRecipe: viewModel.parsedRecipe,
            isTemplate: true,
          ),
        ),
      );
    } else if (context.mounted && viewModel.hasError) {
      // Use UtilityComponents.showErrorSnackbar
      UtilityComponents.showErrorSnackbar(context, viewModel.error!);
    }
  }

  /// BUT-1037: non-blocking confirm shown when the pasted text fails the
  /// recipe-likeness heuristic. Returns true if the user chooses to import
  /// anyway (proceed to the paid LLM parse), false to back out.
  Future<bool> _confirmNonRecipeImport(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.importNotRecipeTitle),
        content: Text(dialogContext.l10n.importNotRecipeBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.importNotRecipeConfirm),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TextImportViewModel>();

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.importFromSocialMedia)),
      body: SafeArea(
        // ✅ RESPONSIVE: Center and constrain content on large screens
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: LayoutComponents.valueFor(
                context: context,
                mobile: double.infinity,
                tablet: 700,
                desktop: 800,
              ),
            ),
            child: SingleChildScrollView(
              padding: AppDimensions.responsiveContentPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Instruktionstext
                  _buildInstructions(context),
                  const SizedBox(height: AppDimensions.spacingXl),

                  // Show if recipe comes from URL
                  if (viewModel.sourceUrl != null) ...[
                    SourceUrlDisplay(sourceUrl: viewModel.sourceUrl!),
                    const SizedBox(height: AppDimensions.spacingM),
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
                    const SizedBox(height: AppDimensions.spacingM),
                  ],

                  // Text field for recipe
                  _buildTextInput(context, viewModel),
                  const SizedBox(height: AppDimensions.spacingXl),

                  // ✅ MIGRERAD: ActionButton.primary → UtilityComponents.primaryButton
                  UtilityComponents.primaryButton(
                    context,
                    label: context.l10n.importPreviewAndEdit,
                    icon: Icons.preview,
                    onPressed: viewModel.isParsing || !viewModel.canParse
                        ? null
                        : () => _parseAndNavigate(context),
                    isLoading: viewModel.isParsing,
                    loadingText: context.l10n.importParsingText,
                    isExpanded: true,
                  ),

                  // Error message
                  if (viewModel.hasError) ...[
                    const SizedBox(height: AppDimensions.spacingM),
                    StateWidget.error(
                      message: viewModel.error!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructions(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: AppDimensions.iconSizeM,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppDimensions.spacingS),
              Text(
                context.l10n.importTipsTitle,
                style: AppTextStyles.labelLarge.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingM),
          Text(
            context.l10n.importTipsContent,
            style: AppTextStyles.bodySmall,
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

    return Container(
      constraints: const BoxConstraints(
        minHeight: 200,
        maxHeight: 400,
      ),
      child: TextField(
        controller: _textController,
        onChanged: (text) => _onTextChanged(text, viewModel),
        decoration: InputDecoration(
          hintText: context.l10n.importPasteRecipeHint,
          hintMaxLines: 10,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
        ),
        keyboardType: TextInputType.multiline,
        maxLines: null,
        maxLength: 10000,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: AppTextStyles.bodyMedium,
      ),
    );
  }
}
