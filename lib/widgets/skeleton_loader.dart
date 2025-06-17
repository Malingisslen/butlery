// lib/widgets/skeleton_loader.dart

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Återanvändbar skeleton loader med shimmer-effekt
class SkeletonLoader extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final EdgeInsets? margin;

  const SkeletonLoader({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.margin,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius ?? AppTheme.smallRadius,
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.grey[300]!, Colors.grey[100]!, Colors.grey[300]!],
          stops: const [0.0, 0.5, 1.0],
          transform: _GradientRotation(_shimmerController),
        ),
      ),
    );
  }
}

/// Transform för shimmer-effekt
class _GradientRotation extends GradientTransform {
  final Animation<double> animation;
  // ignore: prefer_const_constructors_in_immutables
  _GradientRotation(this.animation);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final double x = animation.value * 3 - 1;
    return Matrix4.translationValues(bounds.width * x, 0, 0);
  }
}

/// Skeleton för RecipeCard
class RecipeCardSkeleton extends StatelessWidget {
  const RecipeCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSm,
        vertical: AppTheme.spacingXs,
      ),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.mediumRadius),
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacingSm),
          child: Row(
            children: [
              // Bild skeleton
              SkeletonLoader(
                width: 80,
                height: 80,
                borderRadius: AppTheme.smallRadius,
              ),
              SizedBox(width: AppTheme.spacingSm),
              // Text content skeleton
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titel
                    SkeletonLoader(
                      height: 20,
                      width: double.infinity,
                      margin: EdgeInsets.only(bottom: AppTheme.spacingXs),
                    ),
                    // Beskrivning rad 1
                    SkeletonLoader(
                      height: 14,
                      width: double.infinity,
                      margin: EdgeInsets.only(bottom: AppTheme.spacingXxs),
                    ),
                    // Beskrivning rad 2
                    SkeletonLoader(
                      height: 14,
                      width: 150,
                      margin: EdgeInsets.only(bottom: AppTheme.spacingXs),
                    ),
                    // Taggar
                    Row(
                      children: [
                        SkeletonLoader(
                          height: 24,
                          width: 60,
                          borderRadius: AppTheme.roundRadius,
                          margin: EdgeInsets.only(right: AppTheme.spacingXs),
                        ),
                        SkeletonLoader(
                          height: 24,
                          width: 80,
                          borderRadius: AppTheme.roundRadius,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lista med skeleton loaders
class RecipeListSkeleton extends StatelessWidget {
  final int itemCount;

  const RecipeListSkeleton({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
      itemCount: itemCount,
      itemBuilder: (context, index) => const RecipeCardSkeleton(),
    );
  }
}
