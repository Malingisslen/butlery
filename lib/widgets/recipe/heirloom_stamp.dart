/// Heirloom stamp overlay — a square rust-colored corner badge rendered on
/// top of heirloom source images to signal provenance ("Från farmor, 1978").
///
/// BUT-410: Visual cue that a recipe carries hand-written origin metadata.
/// Design: solid rust background, cream text, NO BorderRadius (matches the
/// mockup's square design language).

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/recipe/heirloom_metadata.dart';

/// Rust corner stamp showing writer + year on top of an heirloom image.
///
/// Renders nothing (SizedBox.shrink) when there's no writerName AND no year —
/// we only stamp the image when we have something worth stamping.
class HeirloomStamp extends StatelessWidget {
  final HeirloomMetadata heirloom;

  /// Alignment within the parent Stack. Defaults to top-right so the stamp
  /// sits on the corner of the image like a physical postage stamp.
  final AlignmentGeometry alignment;

  const HeirloomStamp({
    super.key,
    required this.heirloom,
    this.alignment = Alignment.topRight,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = heirloom.writerName;
    final year = heirloom.year;

    // Nothing to stamp with — skip rather than render an empty badge.
    if ((name == null || name.isEmpty) && year == null) {
      return const SizedBox.shrink();
    }

    final label = _buildLabel(context, name, year);

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.all(AppDimensions.spacingS),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingS,
          vertical: AppDimensions.spacingXs,
        ),
        decoration: BoxDecoration(
          color: cs.secondary,
          // Square-corner design language — no BorderRadius anywhere.
        ),
        child: Text(
          label,
          style: AppTextStyles.badgeLarge.copyWith(
            color: cs.surface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Compose the display label. Uses localized `heirloomFrom` when both
  /// writer and year are present; otherwise falls back to the one value
  /// that exists.
  String _buildLabel(BuildContext context, String? name, int? year) {
    if (name != null && name.isNotEmpty && year != null) {
      return context.l10n.heirloomFrom(name, year);
    }
    if (name != null && name.isNotEmpty) return name;
    return year!.toString();
  }
}
