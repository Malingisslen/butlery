// lib/views/quick_capture_view.dart

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_form_state.dart';

/// Lightweight recipe quick capture — just a title and optional meal type.
class QuickCaptureView extends StatelessWidget {
  const QuickCaptureView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => _QuickCaptureViewModel(),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.quickCaptureTitle),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: LayoutComponents.valueFor(
                context: context,
                mobile: double.infinity,
                tablet: 500,
                desktop: 600,
              ),
            ),
            child: Padding(
              padding: AppDimensions.responsiveContentPadding(context),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppDimensions.spacingXl),
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: context.l10n.quickCaptureTitleHint,
                      ),
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
                    const SizedBox(height: AppDimensions.spacingXl),
                    _MealTypeSelector(
                      selected: vm.mealType,
                      onChanged: vm.setMealType,
                    ),
                    const Spacer(),
                    // BUT-403: `btn-quick-save` identifier for browser a11y.
                    Semantics(
                      identifier: 'btn-quick-save',
                      button: true,
                      enabled: !vm.isSaving,
                      label: context.l10n.quickCaptureSave,
                      child: FilledButton(
                        key: const ValueKey('test-quick-capture-save'),
                        onPressed: vm.isSaving ? null : () => _save(vm),
                        child: vm.isSaving
                            ? const LoadingIndicator(
                                size: AppDimensions.iconSizeS,
                                strokeWidth: 2,
                              )
                            : Text(context.l10n.quickCaptureSave),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXl),
                  ],
                ),
              ),
            ),
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
      SnackBarUtils.showError(context, vm.error!);
    }
  }
}

/// Meal type chip selector.
class _MealTypeSelector extends StatelessWidget {
  const _MealTypeSelector({
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  static const _mealTypes = RecipeFormState.mealTypes;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimensions.spacingSm,
      runSpacing: AppDimensions.spacingSm,
      children: _mealTypes.map((type) {
        final isSelected = type == selected;
        return ChoiceChip(
          label: Text(type),
          selected: isSelected,
          onSelected: (_) => onChanged(type),
        );
      }).toList(),
    );
  }
}

/// Minimal ViewModel for quick capture — handles save + loading/error state.
class _QuickCaptureViewModel extends ChangeNotifier {
  final UnifiedRecipeService _recipeService =
      ServiceLocator.get<UnifiedRecipeService>();

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
      _isSaving = false;
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }
}
