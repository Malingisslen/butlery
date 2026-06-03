/// Text import view for parsing recipes from social media and copied text.

// lib/views/fran_sociala_medier_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/viewmodels/text_import_viewmodel.dart';
import 'package:butlery/views/skriv_sjalv_recept_view.dart';
import 'package:butlery/widgets/common/utility_components.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/source_url_display.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/logger.dart';

/// Text import view for parsing recipes from copied text.
class FranSocialaMedierView extends StatefulWidget {
  final String? initialText;
  final String? sourceUrl;

  const FranSocialaMedierView({
    super.key,
    this.initialText,
    this.sourceUrl,
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
      ),
    );
  }
}

class _FranSocialaMedierViewContent extends StatefulWidget {
  final String? initialText;
  final String? sourceUrl;

  const _FranSocialaMedierViewContent({
    this.initialText,
    this.sourceUrl,
  });

  @override
  State<_FranSocialaMedierViewContent> createState() =>
      _FranSocialaMedierViewContentState();
}

class _FranSocialaMedierViewContentState
    extends State<_FranSocialaMedierViewContent> {
  /// BUT-915: single global key — text-import is a CREATE flow with
  /// one-at-a-time user intent. Unlike per-recipe comment drafts, there's
  /// no multi-instance isolation concern.
  static const String _draftPrefsKey = 'text_import_draft_v1';

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
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_draftPrefsKey);
      if (saved != null && saved.isNotEmpty && mounted) {
        _textController.text = saved;
        context.read<TextImportViewModel>().updateInputText(saved);
      }
    } catch (e) {
      AppLogger.warning('FranSocialaMedierView: failed to load draft ($e)');
    }
  }

  Future<void> _saveDraft(String text) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (text.isEmpty) {
        await prefs.remove(_draftPrefsKey);
      } else {
        await prefs.setString(_draftPrefsKey, text);
      }
    } catch (e) {
      AppLogger.warning('FranSocialaMedierView: failed to save draft ($e)');
    }
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftPrefsKey);
    } catch (e) {
      AppLogger.warning('FranSocialaMedierView: failed to clear draft ($e)');
    }
  }

  void _onTextChanged(String text, TextImportViewModel viewModel) {
    viewModel.updateInputText(text);
    // Eager save — pasted recipes are larger than comments, but write
    // volume is still bounded (one save per keystroke; SharedPreferences
    // is isolate-fenced so it doesn't block input latency).
    _saveDraft(text);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _parseAndNavigate(BuildContext context) async {
    final viewModel = context.read<TextImportViewModel>();
    final success = await viewModel.parseText();

    if (success && context.mounted) {
      // User explicitly moved past the input stage — drop the draft so the
      // next visit to this surface starts blank.
      await _clearDraft();
      if (!context.mounted) return;
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
