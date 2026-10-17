// lib/views/quick_capture_view.dart

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_form_state.dart';
import 'package:butlery/widgets/common/buttons/choice_option.dart';
import 'package:butlery/widgets/common/layout/layout_containers.dart';
import 'package:butlery/widgets/common/input/field_error_line.dart';
import 'package:butlery/widgets/common/input/labeled_field.dart';

/// Lightweight recipe quick capture — just a title and optional meal type.
class QuickCaptureView extends StatelessWidget {
  const QuickCaptureView({super.key, @visibleForTesting this.recipeService});

  /// Test seam: when supplied, the quick-capture VM uses this service instead
  /// of resolving [UnifiedRecipeService] from the [ServiceLocator]. Production
  /// callers pass nothing, so the default ServiceLocator lookup is unchanged.
  @visibleForTesting
  final UnifiedRecipeService? recipeService;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => _QuickCaptureViewModel(recipeService: recipeService),
      child: const _QuickCaptureViewContent(),
    );
  }
}

class _QuickCaptureViewContent extends StatefulWidget {
  const _QuickCaptureViewContent();

  @override
  State<_QuickCaptureViewContent> createState() =>
      _QuickCaptureViewContentState();
}

class _QuickCaptureViewContentState extends State<_QuickCaptureViewContent> {
  final _titleController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<_QuickCaptureViewModel>();

    // A focus mode under Lägg till recept: no tab bar (Malin 2026-10-13, B-54).
    return ButleryPage.undersida(
      title: context.l10n.addSheetQuickSaveTitle,
      showTabBar: false,
      width: PageWidth.compact,
      bottomNavigationBar: BottomActionContainer(
        // BUT-403: `btn-quick-save` identifier for browser a11y.
        child: Semantics(
          identifier: 'btn-quick-save',
          // The view's one primary action (Grafisk manual v6:219). Busy keeps
          // the name and draws the plate line.
          child: FormButton(
            key: const ValueKey('test-quick-capture-save'),
            label: context.l10n.quickCaptureSave,
            busy: vm.isSaving,
            onPressed: () => _save(vm),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: AppDimensions.responsiveContentPadding(context),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppDimensions.space32),
              LabeledField(
                label: context.l10n.quickCaptureTitleHint,
                child: TextFormField(
                  controller: _titleController,
                  errorBuilder: FieldErrorLine.builder,
                  style: AppTextStyles.bodyLarge,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(vm),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.l10n.validationTitleCannotBeEmpty;
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: AppDimensions.space24),
              LabeledField(
                label: context.l10n.importMealType,
                child: ChoiceOptionWrap<String>(
                  values: RecipeFormState.mealTypes,
                  labelOf: (type) => type,
                  selected: vm.mealType,
                  onChanged: vm.setMealType,
                ),
              ),
              const SizedBox(height: AppDimensions.space16),
              Text(
                context.l10n.quickCaptureHelp,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save(_QuickCaptureViewModel vm) async {
    if (!_formKey.currentState!.validate()) return;

    final recipe = await vm.save(_titleController.text.trim());

    if (!mounted) return;

    if (recipe != null) {
      Navigator.pop(context);
      SnackBarUtils.showSuccess(
        context,
        context.l10n.quickCaptureSaved,
        actionLabel: context.l10n.quickCaptureEditAction,
        onAction: () {
          Navigator.pushNamed(context, Routes.editRecipe, arguments: recipe);
        },
      );
    } else if (vm.error != null) {
      // The sheet stays open with the title and meal type the user chose
      // (content-style-guide.md:92).
      SnackBarUtils.showFailure(
        context,
        what: vm.error!,
        preserved: context.l10n.errorPreservedForm,
      );
    }
  }
}

/// Minimal ViewModel for quick capture — handles save + loading/error state.
class _QuickCaptureViewModel extends ChangeNotifier {
  _QuickCaptureViewModel({UnifiedRecipeService? recipeService})
    : _recipeService =
          recipeService ?? ServiceLocator.get<UnifiedRecipeService>();

  final UnifiedRecipeService _recipeService;

  String _mealType = 'Middag';
  bool _isSaving = false;
  String? _error;
  bool _disposed = false;

  String get mealType => _mealType;
  bool get isSaving => _isSaving;
  String? get error => _error;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  void setMealType(String type) {
    _mealType = type;
    notifyListeners();
  }

  Future<Recipe?> save(String title) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final recipe = Recipe(
        core: RecipeCore(
          id: const Uuid().v4(),
          title: title,
          description: '',
          ingredients: const [],
          instructions: const [],
          mealType: _mealType,
          createdAt: clock.now(),
          updatedAt: clock.now(),
        ),
        type: RecipeType.personal,
      );

      final result = await _recipeService.personal.addUnifiedRecipe(recipe);

      _isSaving = false;
      if (result.isSuccess) {
        notifyListeners();
        return recipe;
      } else {
        _error = result.message;
        notifyListeners();
        return null;
      }
    } catch (e) {
      AppLogger.error('Quick capture save failed', e);
      _isSaving = false;
      // What failed, never the exception (content-style-guide.md:95).
      _error = AppLocale.current.recipeSaveFailed;
      notifyListeners();
      return null;
    }
  }
}
