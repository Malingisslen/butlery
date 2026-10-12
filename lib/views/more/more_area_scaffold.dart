// lib/views/more/more_area_scaffold.dart
//
// The page under each row of Konto & app in Mer: the subpage bar named as
// its row, over sections of rows.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';

class MoreAreaScaffold extends StatelessWidget {
  /// A page reached only from Mer, so Back is named "Tillbaka till Mer".
  const MoreAreaScaffold({
    required this.title,
    required this.sections,
    this.header,
    super.key,
  }) : _backTo = null,
       _onlyFromMore = true;

  /// A page with other ways in: Back is named after [backTo] when the caller
  /// gives one, and is plain "Tillbaka" otherwise.
  const MoreAreaScaffold.backTo(
    String? backTo, {
    required this.title,
    required this.sections,
    this.header,
    super.key,
  }) : _backTo = backTo,
       _onlyFromMore = false;

  /// The page's title, which is also the name of the row that opens it.
  final String title;

  final List<Widget> sections;

  /// A band that runs the full width of the page above the sections, such
  /// as Min samling's figures.
  final Widget? header;

  final String? _backTo;
  final bool _onlyFromMore;

  @override
  Widget build(BuildContext context) {
    return ButleryPage.undersida(
      title: title,
      backTo: _onlyFromMore ? context.l10n.moreTitle : _backTo,
      body: header == null
          ? ListView(
              padding: ButleryPageBody.margin(
                context,
                bottom: AppDimensions.space24,
              ),
              children: sections,
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: AppDimensions.space24),
              children: [
                header!,
                Padding(
                  padding: ButleryPageBody.margin(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: sections,
                  ),
                ),
              ],
            ),
    );
  }
}
