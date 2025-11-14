/// Comprehensive styled widgets barrel providing centralized access to design system components.
///
/// This barrel file consolidates all styled widget exports to eliminate design-in-views violations
/// and provide centralized access to the complete design system. It serves as the single import
/// point for all styled components, ensuring consistent design patterns throughout the application
/// and simplifying widget imports for developers.
///
/// **Design System Organization:**
/// - **StyledButton**: Comprehensive button variants and interaction patterns
/// - **StyledCard**: Card layouts with proper elevation and content organization
/// - **StyledContainer**: Layout containers with consistent spacing and theming
/// - **StyledInput**: Form input components with validation and styling integration
///
/// **Usage:**
/// ```dart
/// import 'package:butlery/widgets/styled/styled_widgets.dart';
/// 
/// // Access all styled components
/// StyledButton.primary(text: 'Save', onPressed: () {})
/// StyledCard.recipe(child: recipeContent)
/// StyledContainer.section(child: formSection)
/// ```
///
/// **Consolidation Impact:**
/// This barrel eliminates the need for multiple individual imports while providing
/// comprehensive access to the consolidated design system that replaces hundreds
/// of duplicate styling implementations throughout the application codebase.

// styled_container.dart removed - dead code
export 'styled_button.dart';
export 'styled_card.dart';
export 'styled_input.dart';