/// Recipe addition view with multiple import method options.

// lib/views/lagg_till_recept_view.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/layout_components.dart';
// Removed unused dialog_service import
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Recipe addition view with grid of import method options.
class LaggTillReceptView extends StatelessWidget {
  const LaggTillReceptView({super.key});

  void _navigate(BuildContext context, String routeName) {
    Navigator.pushNamed(context, routeName);
  }

  @override
  Widget build(BuildContext context) {
    // ✅ RESPONSIVE: Get responsive padding and spacing
    final padding = AppDimensions.responsiveContentPadding(context);
    final spacing = LayoutComponents.valueFor(
      context: context,
      mobile: AppDimensions.spacingL,
      tablet: AppDimensions.spacingXl,
      desktop: AppDimensions.spacingXl * 1.5,
    );

    return LayoutComponents.mainMenu(
      currentIndex: 1,
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
            child: Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Hur vill du lägga till ditt recept?',
                    style: AppTextStyles.headlineSmall,
                    textAlign: LayoutComponents.isDesktop(context)
                        ? TextAlign.center
                        : TextAlign.start,
                  ),
                  SizedBox(height: spacing),

                  // Recipe import options - all social/URL routes go to unified SmartImport
                  LayoutComponents.recipeUploadButtonGrid(
                    context,
                    buttons: [
                      {
                        'label': 'YOUTUBE',
                        'icon': Icons.play_circle,
                        'onPressed': () => _navigate(context, '/smartImport'),
                      },
                      {
                        'label': 'FOTO',
                        'icon': Icons.photo_camera,
                        'onPressed': () => _navigate(context, '/photoImport'),
                      },
                      {
                        'label': 'LÄNK',
                        'icon': Icons.link,
                        'onPressed': () => _navigate(context, '/smartImport'),
                      },
                      {
                        'label': 'INSTAGRAM',
                        'icon': Icons.camera_alt,
                        'onPressed': () => _navigate(context, '/smartImport'),
                      },
                      {
                        'label': 'TIKTOK',
                        'icon': Icons.music_note,
                        'onPressed': () => _navigate(context, '/smartImport'),
                      },
                      {
                        'label': 'SKRIV SJÄLV',
                        'icon': Icons.edit,
                        'onPressed': () => _navigate(context, '/skrivSjalv'),
                      },
                    ],
                    archiveButton: {
                      'label': 'ARKIV',
                      'icon': Icons.archive,
                      'onPressed': () => _navigate(context, '/importFranArkiv'),
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}