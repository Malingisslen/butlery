import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/layout/word_fit.dart';

/// What every admin tab is made of under the shell's bar: a light header with
/// the tab's title and its own actions (refresh, export), an optional strip
/// under it (the feedback filter), and the body.
class AdminTabPage extends StatelessWidget {
  const AdminTabPage({
    required this.title,
    required this.body,
    this.actions = const [],
    this.below,
    super.key,
  });

  final String title;
  final List<Widget> actions;
  final Widget? below;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.space16,
              AppDimensions.space8,
              AppDimensions.space8,
              AppDimensions.space8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: WholeWordText(
                      title,
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ),
                ...actions,
              ],
            ),
          ),
          ?below,
          Expanded(child: body),
        ],
      ),
    );
  }
}
