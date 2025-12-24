import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/layout_components.dart';

/// Responsive wrapper for dashboard content with center + constrain pattern.
class ResponsiveDashboardWrapper extends StatelessWidget {
  final Widget child;
  final bool scrollable;

  const ResponsiveDashboardWrapper({
    super.key,
    required this.child,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: LayoutComponents.valueFor(
            context: context,
            mobile: double.infinity,
            tablet: 900,
            desktop: 1200,
          ),
        ),
        child: Padding(
          padding: AppDimensions.responsiveContentPadding(context),
          child: child,
        ),
      ),
    );

    if (scrollable) {
      return SingleChildScrollView(child: content);
    }
    return content;
  }
}
