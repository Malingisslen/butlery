/// P4-U05, P4-U06, P4-U07: the recipe views and their image and cooking
/// widgets load with the plate line or a still plate, never a spinner, and
/// never with a textless StateWidget.loading() (Grafisk manual v6:209;
/// Komponentark v1:303-309; the unit test plans: "ingen textlös
/// StateWidget.loading() och ingen LoadingIndicator", "ingen
/// LinearProgressIndicator i image_picker_dialogs").
///
/// Read from the source, the way architecture_test.dart reads it, so a
/// spinner put back in any of these files fails here.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _files = [
  'lib/views/recipe_detail_view.dart',
  'lib/views/recipe_detail/fullscreen_image_viewer.dart',
  'lib/views/recipe_detail/handlers/recipe_personal_tag_handler.dart',
  'lib/views/recipe_detail/handlers/recipe_tagging_handler.dart',
  'lib/widgets/recipe/comment_form_widget.dart',
  'lib/widgets/recipe/comment_image_attachments.dart',
  'lib/widgets/recipe/cook_snap_gallery.dart',
  'lib/widgets/recipe/cook_snap_photo_carousel.dart',
  'lib/widgets/recipe/heirloom_section.dart',
  'lib/widgets/recipe/ingredient_substitution_sheet.dart',
  'lib/views/cooking_mode_view.dart',
  'lib/widgets/cooking/voice_assist_button.dart',
  'lib/widgets/voice/voice_prompt_button.dart',
  'lib/views/edit_recipe_view.dart',
  'lib/views/skriv_sjalv_recept_view.dart',
  'lib/views/quick_capture_view.dart',
  'lib/widgets/image/avatar_image_widget.dart',
  'lib/widgets/image/components/empty_image_state.dart',
  'lib/widgets/image/components/image_grid_widgets.dart',
  'lib/widgets/image/components/upload_progress_widgets.dart',
  'lib/widgets/image/editable_image_widget.dart',
  'lib/widgets/image/image_components.dart',
  'lib/widgets/image/image_picker_dialogs.dart',
  'lib/widgets/image/image_picker_widget.dart',
  'lib/widgets/image/simple_image_widget.dart',
];

final _forbidden = <String, RegExp>{
  'LoadingIndicator': RegExp(r'\bLoadingIndicator\b'),
  'CircularProgressIndicator': RegExp(r'\bCircularProgressIndicator\b'),
  'LinearProgressIndicator': RegExp(r'\bLinearProgressIndicator\b'),
  'textless StateWidget.loading()': RegExp(r'StateWidget\.loading\(\s*\)'),
};

void main() {
  for (final path in _files) {
    test('$path loads without a spinner', () {
      final source = File(path).readAsStringSync();
      for (final entry in _forbidden.entries) {
        expect(
          entry.value.hasMatch(source),
          isFalse,
          reason: '$path uses ${entry.key}',
        );
      }
    });
  }
}
