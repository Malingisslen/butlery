/// Import first recipe page for the onboarding wizard.
import 'package:flutter/material.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

class OnboardingImportPage extends StatelessWidget {
  const OnboardingImportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppDimensions.spacingXl),
          Text(
            'Importera ditt forsta recept',
            style: AppTextStyles.headlineMedium.copyWith(
              color: cs.primary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            'Kom igang snabbt genom att importera ett recept fran webben '
            'eller ett foto.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          // URL import card
          _ImportOptionCard(
            icon: Icons.link,
            title: 'Fran en webbadress',
            description: 'Klistra in en lank till ett recept',
            onTap: () {
              Navigator.of(context).pushNamed(Routes.importViaUrl);
            },
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          // Photo import card
          _ImportOptionCard(
            icon: Icons.camera_alt_outlined,
            title: 'Importera fran foto',
            description: 'Ta ett foto eller valj fran galleriet',
            onTap: () {
              Navigator.of(context).pushNamed(Routes.photoImport);
            },
          ),
          const Spacer(),
          Center(
            child: Text(
              'Du kan hoppa over detta steg och importera senare.',
              style: AppTextStyles.bodySmall.copyWith(
                color: cs.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLg),
        ],
      ),
    );
  }
}

class _ImportOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _ImportOptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          border: Border.all(color: cs.outlineVariant),
        ),
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: AppDimensions.opacityLight),
              ),
              child: Icon(
                icon,
                size: AppDimensions.iconSizeL,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.titleMedium),
                  const SizedBox(height: AppDimensions.spacingXs),
                  Text(
                    description,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: cs.outline,
            ),
          ],
        ),
      ),
    );
  }
}
