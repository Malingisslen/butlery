// lib/widgets/common/list/person_check_row.dart
//
// One person in a list you tick people from (Skarmar v12 del 3 'Ny delad
// inköpslista', "Dela med"): the avatar, the name with what it is beside it
// in the muted tone, the square box at the end, and a hairline under. Every
// picker that chooses people draws this row, so none of them sets its own box.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/input/butlery_checkbox.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/common/avatar_circle.dart';

class PersonCheckRow extends StatelessWidget {
  const PersonCheckRow({
    required this.name,
    required this.checked,
    required this.onChanged,
    this.avatarUrl,
    this.detail,
    super.key,
  });

  final String name;
  final String? avatarUrl;

  /// Set after the name in the secondary tone, such as "grupp, 4 pers".
  final String? detail;

  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Semantics(
        label: detail == null ? name : '$name, $detail',
        checked: checked,
        excludeSemantics: true,
        onTap: () => onChanged(!checked),
        child: PressFill(
          surface: PressSurface.base,
          child: InkWell(
            onTap: () => onChanged(!checked),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppDimensions.minTouchTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimensions.space8,
                ),
                child: Row(
                  children: [
                    AvatarCircle(imageUrl: avatarUrl, displayName: name),
                    const SizedBox(width: AppDimensions.space12),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: name,
                          style: AppTextStyles.bodyBold.copyWith(
                            color: cs.onSurface,
                          ),
                          children: [
                            if (detail != null)
                              TextSpan(
                                text: ' · $detail',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.space12),
                    ButleryCheckboxMark(checked: checked),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
