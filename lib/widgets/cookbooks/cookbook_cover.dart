import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/tagging/cookbook_details.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/image/simple_image_widget.dart';

/// The cover colours a cookbook can have (BUT-1325). They reuse the
/// shopping categories' decor colours: decor, never information, and the
/// book's name always says which book it is.
class CookbookCoverPalette {
  const CookbookCoverPalette._();

  static const List<String> keys = [
    'moss',
    'brick',
    'brown',
    'sand',
    'grain',
    'sage',
  ];

  static Color color(BuildContext context, String key) {
    final c = context.modeColors;
    return switch (key) {
      'brick' => c.categoryMeatFish,
      'brown' => c.categoryDryGoods,
      'sand' => c.categoryDairy,
      'grain' => c.categoryBreadGrains,
      'sage' => c.categoryFrozen,
      _ => c.categoryVegetables,
    };
  }

  static String name(BuildContext context, String key) {
    final l = context.l10n;
    return switch (key) {
      'brick' => l.cookbookColorBrick,
      'brown' => l.cookbookColorBrown,
      'sand' => l.cookbookColorSand,
      'grain' => l.cookbookColorGold,
      'sage' => l.cookbookColorSage,
      _ => l.cookbookColorMoss,
    };
  }

  /// The theme's ink or paper, whichever reads better on [background].
  static Color textOn(BuildContext context, Color background) {
    final cs = Theme.of(context).colorScheme;
    final ink = cs.onSurface;
    final paper = cs.surface;
    return contrastRatio(ink, background) >= contrastRatio(paper, background)
        ? ink
        : paper;
  }

  static double contrastRatio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }
}

/// A book on the shelf or the top of an open book: the photo or the colour,
/// with the title on a plate so it stays readable on any photo.
class CookbookCoverView extends StatelessWidget {
  const CookbookCoverView({
    required this.name,
    required this.cover,
    required this.imageUrl,
    this.subtitle,
    this.titleStyle,
    super.key,
  });

  final String name;
  final CookbookCover cover;

  /// The resolved photo, or null to draw the colour.
  final String? imageUrl;
  final String? subtitle;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final background = CookbookCoverPalette.color(context, cover.colorKey);
    final photo = imageUrl;
    // On a photo the title sits on the colour as a plate, so the contrast
    // is the swatch's and never depends on the picture.
    final plateColor = photo == null ? null : background;
    final textColor = CookbookCoverPalette.textOn(context, background);

    final title = Container(
      color: plateColor,
      padding: photo == null
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingSm,
              vertical: AppDimensions.spacingXs,
            ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: (titleStyle ?? AppTextStyles.titleMedium).copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: AppTextStyles.bodySmall.copyWith(color: textColor),
            ),
        ],
      ),
    );

    return ColoredBox(
      color: background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photo != null)
            Semantics(
              image: true,
              label: context.l10n.a11yCookbookCover(name),
              child: NetworkImageWidget(
                imageUrl: photo,
                enableHapticFeedback: false,
                errorWidget: const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingSm),
            child: Align(alignment: Alignment.bottomLeft, child: title),
          ),
        ],
      ),
    );
  }
}
