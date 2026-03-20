// lib/widgets/menu/menu_rating_section.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/unified_menu_service.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/star_rating_row.dart';

/// Star rating section for saved/shared menus.
/// Displays average rating and allows users to submit their own rating.
class MenuRatingSection extends StatefulWidget {
  final String menuId;

  const MenuRatingSection({
    super.key,
    required this.menuId,
  });

  @override
  State<MenuRatingSection> createState() => _MenuRatingSectionState();
}

class _MenuRatingSectionState extends State<MenuRatingSection> {
  double _averageRating = 0.0;
  double _userRating = 0.0;
  int _ratingCount = 0;
  bool _isLoading = true;
  bool _isSaving = false;

  late final UnifiedMenuService _menuService;
  late final PermissionService _permissionService;

  @override
  void initState() {
    super.initState();
    _menuService = ServiceLocator.get<UnifiedMenuService>();
    _permissionService = ServiceLocator.get<PermissionService>();
    _loadRatings();
  }

  Future<void> _loadRatings() async {
    try {
      final ratings =
          await _menuService.collaborative.getMenuRatings(widget.menuId);
      final average =
          await _menuService.collaborative.getMenuAverageRating(widget.menuId);

      if (!mounted) return;

      // Find current user's rating
      final currentUserId = _permissionService.currentUserId;
      double userRating = 0.0;
      if (currentUserId != null) {
        for (final r in ratings) {
          if (r['userId'] == currentUserId) {
            userRating = (r['rating'] as num?)?.toDouble() ?? 0.0;
            break;
          }
        }
      }

      setState(() {
        _averageRating = average;
        _ratingCount = ratings.length;
        _userRating = userRating;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitRating(double rating) async {
    if (!_permissionService.isAuthenticated) {
      _showMessage(context.l10n.menuMustBeLoggedInToRate, isError: true);
      return;
    }

    setState(() {
      _isSaving = true;
      _userRating = rating;
    });

    try {
      final success = await _menuService.collaborative.rateMenu(
        menuId: widget.menuId,
        rating: rating,
      );

      if (!mounted) return;

      if (success) {
        _showMessage(context.l10n.menuRatingSaved);
        await _loadRatings();
      } else {
        _showMessage(context.l10n.menuRatingFailed, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage(context.l10n.menuRatingFailed, isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmRemoveRating() async {
    final confirmed = await CommonDialogActions.showActionConfirmation(
      context: context,
      title: context.l10n.menuRatingRemoveTitle,
      message: context.l10n.menuRatingRemoveMessage,
      confirmText: context.l10n.menuRatingRemoveConfirm,
      isDangerous: true,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final success =
          await _menuService.collaborative.removeMenuRating(widget.menuId);
      if (!mounted) return;
      if (success) {
        setState(() => _userRating = 0.0);
        _showMessage(context.l10n.menuRatingRemoved);
        await _loadRatings();
      } else {
        _showMessage(context.l10n.menuRatingRemoveError, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage(context.l10n.menuRatingRemoveError, isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    final bc = context.butleryColors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? cs.error : bc.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: _isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(AppDimensions.paddingL),
                child: CircularProgressIndicator(),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section header
                Row(
                  children: [
                    Icon(
                      Icons.star_outlined,
                      color: cs.primary,
                      size: AppDimensions.iconSizeAction,
                    ),
                    const SizedBox(width: AppDimensions.spacingM),
                    Expanded(
                      child: Text(
                        context.l10n.menuRatingTitle,
                        style: AppTextStyles.titleMedium,
                      ),
                    ),
                    if (_ratingCount > 0)
                      Text(
                        context.l10n.menuRatingCount(_ratingCount),
                        style: AppTextStyles.bodySmall,
                      ),
                  ],
                ),

                const SizedBox(height: AppDimensions.spacingMd),

                // Average rating display
                if (_ratingCount > 0) ...[
                  _buildAverageRatingDisplay(),
                  const SizedBox(height: AppDimensions.spacingMd),
                  Divider(color: cs.outlineVariant),
                  const SizedBox(height: AppDimensions.spacingMd),
                ],

                // User's rating input
                _buildUserRatingInput(),
              ],
            ),
    );
  }

  Widget _buildAverageRatingDisplay() {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        // Large average number
        Text(
          _averageRating.toStringAsFixed(1),
          style: AppTextStyles.headlineBold.copyWith(
            color: cs.primary,
          ),
        ),
        const SizedBox(width: AppDimensions.spacingM),
        // Star row for average
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StarRatingRow(
              rating: _averageRating,
              size: 20.0,
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              context.l10n.menuAverageRating(_averageRating.toStringAsFixed(1)),
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUserRatingInput() {
    if (!_permissionService.isAuthenticated) {
      return Column(
        children: [
          Text(
            context.l10n.menuMustBeLoggedInToRate,
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingM),
          FilledButton(
            onPressed: () => Navigator.pushNamed(context, Routes.auth),
            child: Text(context.l10n.authLogIn),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _userRating > 0
              ? context.l10n.menuYourRating
              : context.l10n.menuTapToRate,
          style: AppTextStyles.labelLarge,
        ),
        const SizedBox(height: AppDimensions.spacingM),
        // Interactive star rating
        Row(
          children: [
            StarRatingRow(
              rating: _userRating,
              size: 36.0,
              onRatingChanged: _isSaving ? null : _submitRating,
            ),
            if (_isSaving) ...[
              const SizedBox(width: AppDimensions.spacingM),
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        // Remove rating button
        if (_userRating > 0) ...[
          const SizedBox(height: AppDimensions.spacingSm),
          TextButton(
            onPressed: _isSaving ? null : _confirmRemoveRating,
            child: Text(
              context.l10n.menuRatingRemoveButton,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }

}
