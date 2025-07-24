// lib/widgets/social/groups/group_dialog_implementations.dart

/// Group dialog implementations - Refactored with Single Responsibility Principle
/// 
/// This file now serves as a clean coordinator that exports focused dialog components.
/// Each dialog type has been separated into its own file with single responsibility:
/// 
/// - CreateGroupDialog: Handles group creation with form validation
/// - EditGroupDialog: Handles group editing with pre-populated data
/// - DeleteGroupDialog: Handles group deletion with confirmation
/// - RemoveMemberDialog: Handles member removal with warnings
/// 
/// Shared components have been extracted to reduce code duplication:
/// - EmojiSelector: Reusable emoji selection widget
/// - ErrorDisplayWidget: Consistent error display
/// - WarningDisplayWidget: Consistent warning display  
/// - DialogHeader: Standardized dialog headers
/// - DialogFooter: Standardized dialog footers
/// - GroupValidationUtils: Shared validation logic

// Export individual dialog components
export 'create_group_dialog.dart';
export 'edit_group_dialog.dart';
export 'delete_group_dialog.dart';
export 'remove_member_dialog.dart';

// Export shared components for external use if needed
export 'shared/group_dialog_components.dart';