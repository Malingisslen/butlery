// lib/widgets/common/state/message_states.dart
//
// Felmeddelandets struktur: vad hände · vad bevarades · vad du kan göra.
// Aldrig illustration — det är tomma lägen som får en grönsak.

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/utility_components.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

/// MessageStates - Error, Success, Info, and Warning state implementations
/// Handles different message state variants with appropriate styling.
///
/// Fellaget bar ingen illustration. Den regeln ar designens, inte en
/// smaksak: ett fel ska ga att lasa fort, och en gronsak fordrojer beskedet.
class MessageStates {
  /// Build the error state.
  ///
  /// Felmeddelandets struktur (content-style-guide.md § Felmeddelandets
  /// struktur) är tre delar, alltid i den här ordningen:
  ///
  ///   1. **Vad hände** — konkret, utan skuld. Det är [message], och det är
  ///      rubriken. Ingen generisk överrubrik står ovanför den: "Ett fel
  ///      uppstod" över en rad som redan säger orsaken utplånar del 1.
  ///   2. **Vad bevarades** — [preserved], och bara *om något står på spel*.
  ///      Utelämnas när ingenting riskerade att gå förlorat.
  ///   3. **Vad du kan göra** — [actionLabel] som knapp.
  ///
  /// **Ingen illustration.** Felläget bar tidigare en rödlök. Tomma lägen får
  /// en illustration; fel får det aldrig — designens tillståndsmodell är
  /// uttrycklig på den punkten, och en grönsak mellan användaren och beskedet
  /// gör beskedet svårare att läsa, inte vänligare.
  static Widget buildErrorState(
    BuildContext context, {
    String? title,
    String? message,
    String? preserved,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Color? iconColor,
    double? iconSize,
    EdgeInsets? padding,
  }) {
    final cs = Theme.of(context).colorScheme;
    // Del 1 bär beskedet. En uttrycklig [title] vinner, annars [message]; det
    // generiska fallet finns kvar bara för anropare som ännu inte har en orsak.
    final vadHande = title ?? message ?? context.l10n.commonErrorOccurred;
    // Om både title och message gavs är message den utförliga raden under.
    final utforligt = (title != null && message != null) ? message : null;

    return Center(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppDimensions.spacingXl),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1 · Vad hände
              Text(
                vadHande,
                style: AppTextStyles.emptyStateTitle,
                textAlign: TextAlign.center,
              ),

              if (utforligt != null) ...[
                const SizedBox(height: AppDimensions.spacingM),
                Text(
                  utforligt,
                  style: AppTextStyles.emptyStateBody,
                  textAlign: TextAlign.center,
                ),
              ],

              // 2 · Vad bevarades — bara när något stod på spel
              if (preserved != null) ...[
                const SizedBox(height: AppDimensions.spacingM),
                Text(
                  preserved,
                  style: AppTextStyles.emptyStateBody.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              // 3 · Vad du kan göra
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppDimensions.spacingXl),
                UtilityComponents.outlinedButton(
                  context,
                  label: actionLabel,
                  onPressed: onAction,
                  icon: Icons.refresh,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Build success state
  static Widget buildSuccessState(
    BuildContext context, {
    String? title,
    String? message,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Color? iconColor,
    double? iconSize,
    EdgeInsets? padding,
  }) {
    return Center(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppDimensions.spacingXl),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success ikon
              Icon(
                icon ?? Icons.check_circle_outline,
                size: iconSize ?? AppDimensions.iconSizeXl,
                color: iconColor ?? context.butleryColors.success,
              ),
              const SizedBox(height: AppDimensions.spacingXl),

              // Success titel
              Text(
                title ?? context.l10n.stateSuccessDefault,
                style: AppTextStyles.headlineSmall.copyWith(
                  color: context.butleryColors.success,
                ),
                textAlign: TextAlign.center,
              ),

              // Success meddelande
              if (message != null) ...[
                const SizedBox(height: AppDimensions.spacingM),
                Text(
                  message,
                  style: AppTextStyles.bodyMediumSuccess,
                  textAlign: TextAlign.center,
                ),
              ],

              // Action knapp
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppDimensions.spacingXl),
                UtilityComponents.primaryButton(
                  context,
                  label: actionLabel,
                  onPressed: onAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Build info state
  static Widget buildInfoState(
    BuildContext context, {
    String? title,
    String? message,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Color? iconColor,
    double? iconSize,
    EdgeInsets? padding,
  }) {
    return Center(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppDimensions.spacingXl),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon ?? Icons.info_outline,
                size: iconSize ?? AppDimensions.iconSizeL,
                color: iconColor ?? Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: AppDimensions.spacingXl),
              if (title != null) ...[
                Text(
                  title,
                  style: AppTextStyles.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spacingM),
              ],
              if (message != null) ...[
                Text(
                  message,
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppDimensions.spacingXl),
                UtilityComponents.outlinedButton(
                  context,
                  label: actionLabel,
                  onPressed: onAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Build warning state
  static Widget buildWarningState(
    BuildContext context, {
    String? title,
    String? message,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Color? iconColor,
    double? iconSize,
    EdgeInsets? padding,
  }) {
    return Center(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppDimensions.spacingXl),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon ?? Icons.warning_outlined,
                size: iconSize ?? AppDimensions.iconSizeL,
                color: iconColor ?? context.butleryColors.warning,
              ),
              const SizedBox(height: AppDimensions.spacingXl),
              if (title != null) ...[
                Text(
                  title,
                  style: AppTextStyles.titleLarge.copyWith(
                    color: context.butleryColors.warning,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spacingM),
              ],
              if (message != null) ...[
                Text(
                  message,
                  style: AppTextStyles.bodyMediumWarning,
                  textAlign: TextAlign.center,
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppDimensions.spacingXl),
                UtilityComponents.primaryButton(
                  context,
                  label: actionLabel,
                  onPressed: onAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
