// lib/widgets/common/layout/heading_actions_row.dart
//
// A heading with its actions at the end of the same line ("Medlemmar", Välj,
// + Bjud in). At large text the actions would leave the heading a sliver and
// break its word, so they drop to a line of their own under it.
library;

import 'package:flutter/widgets.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/layout/word_fit.dart';

class HeadingActionsRow extends StatelessWidget {
  const HeadingActionsRow({
    required this.heading,
    required this.actions,
    super.key,
  });

  final Widget heading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return heading;
    if (isLargeText(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading,
          Wrap(
            spacing: AppDimensions.space8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions,
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: heading),
        ...actions,
      ],
    );
  }
}
