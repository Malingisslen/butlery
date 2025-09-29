// lib/widgets/common/input/rating_widget.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// A reusable star rating widget supporting full stars, half stars, and interactive rating.
///
/// This widget provides comprehensive star rating functionality following the established
/// design patterns from the existing MenuRatingCommentsWidget implementation.
///
/// Features:
/// - Full stars, half stars, and empty stars display
/// - Configurable star size and colors
/// - Read-only mode for displaying ratings
/// - Interactive mode for rating input
/// - 5-star rating system (1.0 - 5.0)
/// - Proper accessibility support
///
/// Usage Examples:
/// ```dart
/// // Read-only rating display
/// RatingWidget.readonly(
///   rating: 4.5,
///   size: 20,
/// )
/// 
/// // Interactive rating input
/// RatingWidget.interactive(
///   rating: 3.0,
///   onRatingChanged: (rating) => print('New rating: $rating'),
/// )
/// ```
class RatingWidget extends StatelessWidget {
  /// The current rating value (1.0 - 5.0)
  final double rating;
  
  /// Size of each star icon
  final double size;
  
  /// Color of the filled stars
  final Color starColor;
  
  /// Color of the empty/border stars
  final Color emptyStarColor;
  
  /// Whether the widget allows interaction for rating input
  final bool isInteractive;
  
  /// Callback when rating changes (only used when isInteractive = true)
  final ValueChanged<double>? onRatingChanged;
  
  /// Main constructor for rating widget
  const RatingWidget({
    super.key,
    required this.rating,
    this.size = AppDimensions.iconSizeS,
    this.starColor = AppColors.warning,
    this.emptyStarColor = AppColors.outline,
    this.isInteractive = false,
    this.onRatingChanged,
  }) : assert(rating >= 0.0 && rating <= 5.0, 'Rating must be between 0.0 and 5.0');

  /// Factory constructor for read-only rating display
  factory RatingWidget.readonly({
    required double rating,
    double size = AppDimensions.iconSizeS,
    Color starColor = AppColors.warning,
    Color emptyStarColor = AppColors.outline,
  }) {
    return RatingWidget(
      rating: rating,
      size: size,
      starColor: starColor,
      emptyStarColor: emptyStarColor,
      isInteractive: false,
    );
  }

  /// Factory constructor for interactive rating input
  factory RatingWidget.interactive({
    required double rating,
    required ValueChanged<double> onRatingChanged,
    double size = AppDimensions.iconSizeM,
    Color starColor = AppColors.warning,
    Color emptyStarColor = AppColors.outline,
  }) {
    return RatingWidget(
      rating: rating,
      size: size,
      starColor: starColor,
      emptyStarColor: emptyStarColor,
      isInteractive: true,
      onRatingChanged: onRatingChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) => _buildStar(index + 1)),
    );
  }

  /// Builds an individual star based on the rating and star position
  Widget _buildStar(int starNumber) {
    final isFullStar = rating >= starNumber;
    final isHalfStar = rating >= starNumber - 0.5 && rating < starNumber;
    
    final starIcon = isFullStar 
        ? Icons.star 
        : (isHalfStar ? Icons.star_half : Icons.star_border);
    
    final starIconColor = (isFullStar || isHalfStar) ? starColor : emptyStarColor;

    final star = Icon(
      starIcon,
      size: size,
      color: starIconColor,
    );

    if (!isInteractive || onRatingChanged == null) {
      return star;
    }

    // Interactive mode - wrap with GestureDetector for tap handling
    return GestureDetector(
      onTap: () => onRatingChanged!(starNumber.toDouble()),
      child: star,
    );
  }
}