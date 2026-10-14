// lib/widgets/common/menus/butlery_menu.dart
//
// The ⋯ menu on a card or a header, and the dropdown in a form. A view hands
// over the choices; the glyph, the touch target, the focus ring, the arrow
// colours and the row layout are drawn here.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';

/// One choice in a [ButleryMenu].
class ButleryMenuChoice<T> {
  const ButleryMenuChoice({
    required this.value,
    required this.label,
    this.icon,
    this.danger = false,
    this.enabled = true,
  });

  final T value;
  final String label;
  final IconData? icon;

  /// Drawn in text.danger: the choice removes something.
  final bool danger;
  final bool enabled;
}

/// A button that opens a menu of [choices] and reports the one picked.
class ButleryMenu<T> extends StatelessWidget {
  const ButleryMenu({
    required this.choices,
    required this.onSelected,
    required this.semanticLabel,
    this.icon = ButleryIcons.moreVertical,
    this.iconColor,
    super.key,
  });

  final List<ButleryMenuChoice<T>> choices;
  final ValueChanged<T> onSelected;

  /// What the button opens, from l10n: "Fler val för receptet".
  final String semanticLabel;

  final IconData icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PressFill(
      surface: PressSurface.base,
      child: PopupMenuButton<T>(
        tooltip: semanticLabel,
        icon: ButleryIcon(icon, color: iconColor),
        onSelected: onSelected,
        itemBuilder: (context) => [
          for (final c in choices)
            ButleryMenuItem<T>(
              value: c.value,
              enabled: c.enabled,
              child: Row(
                children: [
                  if (c.icon != null) ...[
                    ButleryIcon(c.icon!, color: c.danger ? cs.error : null),
                    const SizedBox(width: AppDimensions.space8),
                  ],
                  Flexible(
                    child: Text(
                      c.label,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: c.danger ? cs.error : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One option in a [ButleryDropdown].
class ButleryDropdownOption<T> {
  const ButleryDropdownOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// A form field that picks one of [options]. The stored value and the options
/// must come from one read: the framework re-checks that they match on every
/// build.
class ButleryDropdown<T> extends StatelessWidget {
  const ButleryDropdown({
    required this.options,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    this.hint,
    super.key,
  });

  final List<ButleryDropdownOption<T>> options;
  final T? value;

  /// Null disables the field.
  final ValueChanged<T>? onChanged;
  final String? hint;

  /// Names the field for a screen reader, since the chosen value alone does
  /// not.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticLabel,
      child: PressFill(
        surface: PressSurface.base,
        child: DropdownButtonFormField<T>(
          // initialValue is read once; a new value rebuilds the field.
          key: ValueKey<T?>(value),
          initialValue: value,
          isExpanded: true,
          icon: const ButleryIcon(ButleryIcons.chevronDown),
          iconEnabledColor: cs.onSurfaceVariant,
          iconDisabledColor: AppModeColors.textDisabled(cs.brightness),
          hint: hint == null ? null : Text(hint!),
          style: AppTextStyles.bodyMedium.copyWith(color: cs.onSurface),
          items: [
            for (final o in options)
              DropdownMenuItem<T>(value: o.value, child: Text(o.label)),
          ],
          onChanged: onChanged == null
              ? null
              : (v) {
                  if (v != null) onChanged!(v);
                },
        ),
      ),
    );
  }
}
