/// Comprehensive typography system providing unified text styling for the Butlery cooking application.
///
/// This typography system implements a sophisticated hierarchy of text styles that combines Material 3 design
/// principles with culinary-focused readability and Swedish localization preferences. The system provides
/// semantic text styles optimized for recipe content, cooking instructions, metadata, and social interactions
/// while maintaining accessibility compliance and cultural appropriateness for Swedish users.
///
/// **Architecture Integration:**
/// - Implements Material 3 typography specification with cooking-specific customizations
/// - Provides comprehensive text hierarchy for recipe content organization and readability
/// - Integrates with Swedish localization for appropriate text rendering and cultural preferences
/// - Supports accessibility requirements with optimized contrast ratios and readable font sizes
/// - Maintains consistent typography throughout the application with semantic naming conventions
///
/// **Typography Categories:**
/// - **Display Styles**: High-impact text for section headlines and prominent content
/// - **Headline Styles**: Section headers, subsection titles, and content organization
/// - **Title Styles**: Recipe names, dialog titles, and primary content identification
/// - **Body Styles**: Main content text, secondary content, and metadata with optimized readability
/// - **Label Styles**: Button text, form labels, tags, and interface elements
/// - **Semantic Styles**: Specialized styles for recipe metadata, status messages, and user feedback
///
/// **Design Philosophy:**
/// The typography system reflects the clarity and precision of cooking with readable fonts, appropriate
/// sizing for kitchen environments, and hierarchical organization that guides users through complex
/// recipe information and cooking workflows effectively.
///
/// **Key Features:**
/// - Material 3 compliance with cooking-specific font sizing and line height optimization
/// - Swedish language support with appropriate character spacing and rendering
/// - Accessibility-first approach with high contrast ratios and readable sizing
/// - Semantic naming system for consistent application throughout the codebase
/// - Recipe-optimized typography for ingredients, instructions, and cooking metadata
/// - Performance optimization through compile-time constant definitions
///
/// **Usage Examples:**
/// ```dart
/// // Section headers for recipe categories
/// Text(
///   'Middagar',
///   style: AppTextStyles.headlineMedium,
/// );
/// 
/// // Recipe titles with proper hierarchy
/// Text(
///   'Köttbullar med gräddsås',
///   style: AppTextStyles.titleLarge,
/// );
/// 
/// // Recipe metadata for portions and timing
/// Text(
///   '6 portioner | 30 minuter',
///   style: AppTextStyles.recipeMeta,
/// );
/// 
/// // Creating complete TextTheme for MaterialApp
/// MaterialApp(
///   theme: ThemeData(
///     textTheme: AppTextStyles.createTextTheme(),
///   ),
/// );
/// ```

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';

/// Comprehensive typography system implementing unified text styling for cooking-focused user interface design.
///
/// This class serves as the central repository for all text styles used throughout the Butlery application,
/// providing a carefully curated typography hierarchy that combines Material 3 design principles with
/// culinary-specific readability requirements. The system ensures consistent text presentation, accessibility
/// compliance, and cultural appropriateness for Swedish users while optimizing readability in kitchen
/// environments and cooking workflow scenarios.
///
/// **Typography Architecture:**
/// - **Material 3 Integration**: Full Material 3 typography specification with cooking-specific adaptations
/// - **Semantic Organization**: Clear naming conventions that reflect content hierarchy and usage context
/// - **Accessibility Compliance**: High contrast ratios and readable font sizes for all user scenarios
/// - **Cultural Adaptation**: Typography optimized for Swedish language characteristics and reading patterns
/// - **Performance Optimization**: Compile-time constants for efficient rendering and memory usage
///
/// **Design Principles:**
/// The typography reflects the precision and clarity of cooking with readable fonts that work well
/// in various lighting conditions, appropriate sizing for mobile and tablet devices, and hierarchical
/// organization that effectively guides users through complex recipe information and cooking workflows.
class AppTextStyles {
  /// Private constructor to prevent instantiation of utility class
  AppTextStyles._();

  // ===== BASE FONT CONFIGURATION =====

  /// Primary font family for the application - Inter for optimal readability across all content types
  ///
  /// Inter is selected for its excellent readability in digital environments, comprehensive character
  /// support for Swedish text, and optimal rendering across different screen sizes and resolutions.
  /// The font provides consistent baseline alignment and spacing that enhances recipe content readability.
  static const String _primaryFontFamily = 'Inter';

  // ===== HEADING STYLES =====

  /// Display Small text style for prominent section headlines and major content organization.
  ///
  /// This style is designed for high-impact text that introduces major sections of the application,
  /// such as main screen titles, primary navigation labels, and important content categories.
  /// The styling provides strong visual hierarchy while maintaining readability for Swedish text.
  ///
  /// **Usage Examples:**
  /// - Main screen titles ("Mina Recept", "Veckomeny")
  /// - Primary section headers in complex views
  /// - Welcome messages and onboarding titles
  /// - Category headers in discovery and browsing interfaces
  ///
  /// **Typography Specifications:**
  /// - Font Size: 24sp for strong visual presence
  /// - Font Weight: Semi-bold (600) for emphasis without overwhelming
  /// - Color: Dark text for maximum contrast and readability
  /// - Line Height: Default for optimal Swedish character rendering
  static const TextStyle displaySmall = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );


  /// Headline Medium text style for section headers and content category organization.
  ///
  /// This style is specifically designed for recipe category headers such as "Middagar", "Lunch",
  /// "Middag", and other meal category identifiers. The styling provides clear visual separation
  /// between content sections while maintaining the cooking-focused design aesthetic.
  ///
  /// **Usage Examples:**
  /// - Recipe category headers ("Middagar", "Lunch", "Efterrätter")
  /// - Menu section titles in weekly planning
  /// - Content group headers in recipe lists
  /// - Tab labels for major navigation sections
  ///
  /// **Typography Specifications:**
  /// - Font Size: 24sp for prominent section identification
  /// - Font Weight: Bold (700) for strong visual hierarchy
  /// - Color: Section header color for optimal contrast
  /// - Letter Spacing: Tight (-0.25) for compact, professional appearance
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 24, // Increased from 20
    fontWeight: FontWeight.w700,
    color: AppColors.sectionHeader, // Dark for section headers
    letterSpacing: -0.25,
  );

  /// Headline Small text style for subsection titles and secondary content organization.
  ///
  /// This style provides hierarchical organization for content that requires prominent visibility
  /// but operates at a secondary level to main headlines. It's ideal for subsection titles,
  /// dialog headers, and secondary navigation elements throughout the cooking application.
  ///
  /// **Usage Examples:**
  /// - Dialog titles and modal headers
  /// - Subsection titles within recipe categories
  /// - Secondary navigation labels
  /// - Form section headers and group labels
  ///
  /// **Typography Specifications:**
  /// - Font Size: 22sp for clear hierarchy below main headlines
  /// - Font Weight: Semi-bold (600) for emphasis without overpowering
  /// - Color: Dark text for consistent readability
  /// - Line Height: Default for optimal character spacing
  static const TextStyle headlineSmall = TextStyle(
    fontSize: 22, // Increased from 18
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );

  // ===== TITLE STYLES =====

  /// Title Large text style for recipe names and primary content identification.
  ///
  /// This style is designed for recipe titles, dish names, and other primary content identifiers
  /// that require prominent visibility while maintaining readability. The styling is optimized
  /// for Swedish recipe names and cooking terminology with appropriate line height for multi-line
  /// titles and complex dish names commonly found in Swedish cuisine.
  ///
  /// **Usage Examples:**
  /// - Recipe names in lists and detail views ("Köttbullar med gräddsås")
  /// - Dish titles in menu planning and weekly meal organization
  /// - Content titles in shared recipes and social cooking features
  /// - Primary labels in form fields and input components
  ///
  /// **Typography Specifications:**
  /// - Font Size: 17sp for clear recipe name identification
  /// - Font Weight: Semi-bold (600) for emphasis and readability
  /// - Color: Dark text for maximum contrast
  /// - Line Height: 1.3 for optimal multi-line recipe name rendering
  static const TextStyle titleLarge = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
    height: 1.3,
  );

  /// Title Medium text style for secondary recipe names and content titles.
  ///
  /// This style provides a secondary tier of title styling for recipe names in constrained spaces,
  /// card titles, list item headers, and other content that requires title-level emphasis but
  /// operates within smaller interface elements. The styling maintains readability while conserving
  /// space in dense content layouts common in recipe management applications.
  ///
  /// **Usage Examples:**
  /// - Recipe names in compact card layouts
  /// - List tile titles and secondary content headers
  /// - Dialog content titles and form section labels
  /// - Navigation drawer item labels and menu titles
  ///
  /// **Typography Specifications:**
  /// - Font Size: 15sp for clear identification in constrained spaces
  /// - Font Weight: Semi-bold (600) for appropriate emphasis
  /// - Color: Dark text for consistent readability
  /// - Line Height: 1.3 for optimal Swedish text rendering
  static const TextStyle titleMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
    height: 1.3,
  );

  /// Title Small text style for smaller titles and tertiary content identification.
  ///
  /// This style serves as an alias for headlineSmall, providing consistent naming conventions
  /// for components that require smaller title styling. It maintains the same visual properties
  /// while offering semantic clarity for different usage contexts throughout the application.
  ///
  /// **Usage Examples:**
  /// - Small dialog titles and compact modal headers
  /// - Tertiary content labels and minor section headers
  /// - Compact form labels and input group titles
  /// - Secondary navigation elements and menu items
  static const TextStyle titleSmall = headlineSmall;


  // ===== BODY STYLES =====

  /// Body Large text style for main content text and primary reading material.
  ///
  /// This style is designed for the primary content consumption throughout the application,
  /// including recipe instructions, cooking descriptions, ingredient lists, and other main
  /// content that requires extended reading. The styling prioritizes readability with appropriate
  /// line height for comfortable reading of Swedish cooking content and instructions.
  ///
  /// **Usage Examples:**
  /// - Recipe cooking instructions and step-by-step directions
  /// - Ingredient descriptions and preparation notes
  /// - Dialog content text and detailed explanations
  /// - Main body text in articles and informational content
  ///
  /// **Typography Specifications:**
  /// - Font Size: 16sp for optimal reading comfort
  /// - Font Weight: Normal (400) for extended reading without fatigue
  /// - Color: Dark text for maximum contrast and readability
  /// - Line Height: 1.5 for comfortable multi-line reading
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textDark,
    height: 1.5,
  );

  /// Body Medium text style for secondary content and supporting information.
  ///
  /// This style provides readable text for secondary content that supports the main content
  /// without competing for attention. It's designed for supplementary information, descriptions,
  /// and supporting text that enhances the user's understanding of the primary content while
  /// maintaining clear visual hierarchy throughout the cooking application interface.
  ///
  /// **Usage Examples:**
  /// - Recipe descriptions and cooking tips
  /// - User profile information and settings descriptions
  /// - Help text and explanatory content
  /// - Secondary navigation labels and supporting information
  ///
  /// **Typography Specifications:**
  /// - Font Size: 14sp for clear secondary content readability
  /// - Font Weight: Normal (400) for comfortable extended reading
  /// - Color: Medium text color for appropriate visual hierarchy
  /// - Line Height: 1.4 for optimal secondary content presentation
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textMedium,
    height: 1.4,
  );

  /// Body Small text style for metadata and supplementary information display.
  ///
  /// This style is specifically designed for recipe metadata such as serving sizes, cooking times,
  /// difficulty levels, and other supplementary information that provides context without dominating
  /// the interface. The styling uses specialized recipe metadata colors and compact spacing to
  /// efficiently present cooking-specific information that Swedish users expect in recipe applications.
  ///
  /// **Usage Examples:**
  /// - Recipe metadata ("6 portioner | 30 minuter")
  /// - Cooking difficulty and preparation time indicators
  /// - Category labels and content tags
  /// - Status indicators and supplementary information
  ///
  /// **Typography Specifications:**
  /// - Font Size: 13sp for efficient metadata presentation
  /// - Font Weight: Normal (400) for subtle information display
  /// - Color: Recipe metadata color for appropriate visual de-emphasis
  /// - Line Height: 1.3 for compact, efficient information layout
  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    color: AppColors.recipeMeta, // Special color for metadata
    height: 1.3,
  );

  // ===== LABEL STYLES =====

  /// Label Large - For prominent buttons (matching original AppTheme)
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );

  /// Label Medium - For standard buttons (matching original AppTheme)
  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textMedium,
  );

  /// Label Small - For small buttons and tags (matching original AppTheme)
  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textLight,
  );

  // ===== SEMANTIC STYLES =====

  /// Recipe metadata style (portions, time, etc.)
  static TextStyle recipeMeta = bodySmall.copyWith(
    color: AppColors.recipeMeta,
    fontWeight: FontWeight.w500,
  );

  /// Section header style
  static TextStyle sectionHeader = headlineSmall.copyWith(
    color: AppColors.sectionHeader,
    fontWeight: FontWeight.w700,
  );

  /// Section title style (alias for section header)
  static TextStyle sectionTitleStyle = sectionHeader;

  /// Button text style
  static const TextStyle buttonText = labelLarge;
  
  /// Label text style for form fields
  static const TextStyle labelText = labelMedium;
  
  /// Caption text style for helper text
  static const TextStyle captionText = labelSmall;

  /// Primary button text style
  static const TextStyle buttonPrimary = labelLarge;

  /// Button text style (alias)
  static const TextStyle buttonTextStyle = buttonText;

  /// Tab text style
  static const TextStyle tabText = labelMedium;

  /// Navigation text style
  static const TextStyle navigationText = labelSmall;

  /// Error text style
  static TextStyle errorText = bodySmall.copyWith(
    color: AppColors.error,
    fontWeight: FontWeight.w500,
  );

  /// Success text style
  static TextStyle successText = bodySmall.copyWith(
    color: AppColors.success,
    fontWeight: FontWeight.w500,
  );


  // ===== SPECIALIZED STYLES =====

  /// App bar title style
  static const TextStyle appBarTitle = headlineMedium;

  /// Card title style
  static const TextStyle cardTitle = titleMedium;

  /// Card title style (alias)
  static const TextStyle cardTitleStyle = cardTitle;


  /// List tile title style
  static const TextStyle listTileTitle = titleMedium;

  /// List tile subtitle style
  static const TextStyle listTileSubtitle = bodyMedium;

  /// Dialog title style
  static const TextStyle dialogTitle = titleLarge;

  /// Dialog content style
  static const TextStyle dialogContent = bodyLarge;

  /// Snackbar text style
  static const TextStyle snackbarText = bodyMedium;


  /// Hint text style
  static TextStyle hintText = bodyMedium.copyWith(
    color: AppColors.textLight,
  );



  // ===== ADDITIONAL STYLES =====



  // ===== TEXT THEME FACTORY =====

  /// Creates a complete Material 3 TextTheme with comprehensive typography hierarchy for cooking applications.
  ///
  /// This factory method assembles all individual text styles into a cohesive TextTheme that integrates
  /// seamlessly with Material 3 design system while maintaining cooking-specific customizations.
  /// The resulting TextTheme provides consistent typography throughout the application with optimized
  /// readability for recipe content, Swedish localization support, and accessibility compliance.
  ///
  /// Returns a fully configured TextTheme suitable for use with MaterialApp theme configuration
  ///
  /// **TextTheme Integration:**
  /// - Maps all text styles to appropriate Material 3 TextTheme properties
  /// - Ensures consistent typography hierarchy throughout the application
  /// - Provides cooking-optimized text rendering for recipe content and instructions
  /// - Maintains accessibility compliance with appropriate contrast ratios and sizing
  /// - Supports Swedish language characteristics and cultural typography preferences
  ///
  /// **Usage Example:**
  /// ```dart
  /// MaterialApp(
  ///   theme: ThemeData(
  ///     textTheme: AppTextStyles.createTextTheme(),
  ///     colorScheme: AppColors.lightColorScheme,
  ///   ),
  ///   home: RecipeListView(),
  /// );
  /// ```
  static TextTheme createTextTheme() {
    return const TextTheme(
      displaySmall: displaySmall,
      headlineMedium: headlineMedium,
      headlineSmall: headlineSmall,
      titleLarge: titleLarge,
      titleMedium: titleMedium,
      bodyLarge: bodyLarge,
      bodyMedium: bodyMedium,
      bodySmall: bodySmall,
      labelLarge: labelLarge,
      labelMedium: labelMedium,
      labelSmall: labelSmall,
    );
  }

}