import 'package:flutter/material.dart';

import 'package:butlery/core/bootstrap/firebase_env.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// One line above the whole app naming the Firebase project, shown only in
/// builds whose [FirebaseEnv.showBanner] is set, so a staging phone can never
/// be mistaken for the production app.
class StagingBanner extends StatelessWidget {
  const StagingBanner({super.key, required this.env, required this.child});

  final FirebaseEnv env;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!env.showBanner) return child;
    final colors = context.modeColors;
    final topInset = MediaQuery.paddingOf(context).top;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: colors.warning,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppDimensions.space8,
              topInset + AppDimensions.space4,
              AppDimensions.space8,
              AppDimensions.space4,
            ),
            child: Text(
              env.bannerLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(color: colors.onWarning),
            ),
          ),
        ),
        // The banner already covers the status bar, so the app below must
        // not pad for it a second time.
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}
