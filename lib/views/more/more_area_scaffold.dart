// lib/views/more/more_area_scaffold.dart
//
// The page under each row of Konto & app in Mer: the subpage bar named as
// its row, with Back leading to Mer, over sections of rows.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/layout/layout_scaffolds.dart';

class MoreAreaScaffold extends StatelessWidget {
  const MoreAreaScaffold({
    required this.title,
    required this.sections,
    super.key,
  });

  /// The page's title, which is also the name of the row that opens it.
  final String title;

  final List<Widget> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ButleryTopBar.undersida(
        title: title,
        backTo: context.l10n.moreTitle,
      ),
      bottomNavigationBar: LayoutScaffolds.detailBottomNav(context),
      body: SafeArea(
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: EdgeInsetsDirectional.only(
                start: ButleryTopBar.sideMargin(context),
                end: ButleryTopBar.sideMargin(context),
                bottom: AppDimensions.spacingLg,
              ),
              children: sections,
            ),
          ),
        ),
      ),
    );
  }
}
