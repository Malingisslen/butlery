/// Comprehensive recipe addition view providing multiple import methods and creation options for Flutter applications.
/// This module implements sophisticated recipe addition interface following Single Responsibility Principle,
/// specializing in recipe import method selection, navigation coordination, and comprehensive recipe creation workflow.
/// It provides complete recipe addition interface while maintaining clean separation from business logic, data persistence,
/// and state management through modern component architecture and focused navigation coordination.
/// **Single Responsibility Focus:**
/// This module exclusively handles recipe addition UI presentation concerns through theme-centralized architecture:
/// - **Import Method Selection Excellence**: Comprehensive recipe import options including social media, photo, URL, and manual creation
/// - **Navigation Coordination Intelligence**: Advanced navigation management with proper route handling and user flow optimization
/// - **Visual Grid Layout System**: Modern square button grid layout with consistent design and user-friendly organization
/// - **Exit Dialog Integration**: Comprehensive exit confirmation with user safety and navigation protection
/// - **Swedish Localization Excellence**: Complete Swedish language support for recipe addition operations and user feedback
/// **What This Module Does NOT Handle:**
/// - Recipe import business logic and data processing (handled by specialized import ViewModels and services)
/// - Data persistence and recipe storage (handled by recipe repositories and Firebase services)
/// - Import validation and processing (handled by import services and validation infrastructure)
/// - Navigation routing logic (handled by application routing and navigation services)
/// **Recipe Addition View Architecture:**
/// - **Theme-Centralized Design**: Complete migration to UtilityComponents and LayoutComponents for consistent theming
/// - **Square Button Grid Layout**: Modern 2x3 grid layout with specialized recipe import options and visual coordination
/// - **Navigation Facade Pattern**: Clean navigation delegation with proper route management and user flow coordination
/// - **Exit Safety Integration**: Comprehensive exit confirmation with DialogService integration and user protection
/// - **Responsive Design**: Optimized layout for different screen sizes and orientation changes
/// **Usage Examples:**
/// ```dart
/// // Navigate to recipe addition view
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (context) => const LaggTillReceptView(),
///   ),
/// );
/// // The view provides comprehensive recipe addition functionality:
/// // - Social media import options (Instagram, Facebook, TikTok)
/// // - Photo-based recipe import with OCR processing
/// // - URL-based recipe import with web scraping
/// // - Manual recipe creation with form interface
/// // - Archive import with batch processing capabilities
/// // Import method integration:
/// // - Social media import through specialized social media processing
/// // - Photo import with OCR and automatic recipe parsing
/// // - URL import with recipe site recognition and content extraction
/// // - Manual creation with comprehensive recipe form interface
/// // - Archive import with multi-recipe batch processing
/// ```

// lib/views/lagg_till_recept_view.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/layout_components.dart';
// Removed unused dialog_service import
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Comprehensive recipe addition view providing multiple import methods through theme-centralized architecture.
/// Manages complete recipe addition interface enabling import method selection, navigation coordination,
/// and comprehensive recipe creation workflow while maintaining clean separation between UI presentation
/// and business logic through modern component architecture and focused navigation delegation.
/// **Core Responsibilities:**
/// - Advanced import method presentation with social media, photo, URL, and manual creation options
/// - Navigation coordination with proper route handling and user flow optimization through clean delegation
/// - Visual grid layout management with modern square button design and consistent theming
/// - Exit dialog integration with user safety and navigation protection coordination
/// - Swedish localized user experience with comprehensive user guidance and feedback
class LaggTillReceptView extends StatelessWidget {
  /// Creates comprehensive recipe addition view with theme-centralized architecture and navigation coordination.
  /// Establishes recipe addition interface with modern component integration,
  /// navigation management, and comprehensive import method selection
  /// through clean architectural separation and responsive design coordination.
  const LaggTillReceptView({super.key});

  /// Navigate to the specified route
  void _navigate(BuildContext context, String routeName) {
    Navigator.pushNamed(context, routeName);
  }


  /// Comprehensive recipe addition interface construction with theme-centralized components and exit protection.
  /// [context] Build context for theme access and component construction coordination
  /// Constructs complete recipe addition interface featuring theme-centralized component architecture,
  /// exit confirmation dialog, import method selection, and comprehensive navigation functionality
  /// through modern component integration and responsive design coordination.
  /// **Interface Architecture:**
  /// - PopScope integration with exit confirmation and user safety features preventing accidental navigation
  /// - LayoutComponents integration with main menu structure and consistent app navigation
  /// - Theme-centralized design with UtilityComponents and LayoutComponents modern architecture
  /// - Square button grid layout with comprehensive import method selection and visual coordination
  /// - Archive import integration with large button design and specialized functionality
  /// **Import Method Integration:**
  /// - Social media import options with Instagram, Facebook, and TikTok specialized processing
  /// - Photo-based import with OCR processing and automatic recipe parsing coordination
  /// - URL-based import with web scraping and recipe site recognition functionality
  /// - Manual recipe creation with comprehensive form interface and input validation
  /// - Archive import with batch processing and multi-recipe handling capabilities
  /// **User Experience Features:**
  /// - Swedish localized interface with clear user guidance and import method descriptions
  /// - Consistent theming with app design system integration and visual coordination
  /// - Responsive layout with proper spacing and alignment for optimal user experience
  /// - Exit safety with dialog confirmation preventing accidental navigation loss
  /// Returns complete recipe addition interface with comprehensive functionality and modern architecture.
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

                  // Recipe upload button grid using theme-based layout
                  LayoutComponents.recipeUploadButtonGrid(
                    context,
                    buttons: [
                      {
                        'label': 'FACEBOOK',
                        'icon': Icons.facebook,
                        'onPressed': () => _navigate(context, '/franSocialaMedier'),
                      },
                      {
                        'label': 'FOTO',
                        'icon': Icons.photo,
                        'onPressed': () => _navigate(context, '/photoImport'),
                      },
                      {
                        'label': 'LÄNK',
                        'icon': Icons.link,
                        'onPressed': () => _navigate(context, '/importViaUrl'),
                      },
                      {
                        'label': 'INSTAGRAM',
                        'icon': Icons.camera_alt,
                        'onPressed': () => _navigate(context, '/franSocialaMedier'),
                      },
                      {
                        'label': 'TIKTOK',
                        'icon': Icons.music_note,
                        'onPressed': () => _navigate(context, '/franSocialaMedier'),
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