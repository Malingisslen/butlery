import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/share_dialog/share_dialog_header.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  testWidgets('a shared tag is headed "Dela tagg med vänner"', (tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => ShareDialogHeader.build(
            context,
            ShareContentType.personalTag,
            {'tagName': 'Fredagsmys'},
          ),
        ),
      ),
    );

    expect(find.text('Dela tagg med vänner'), findsOneWidget);
    expect(find.text('Fredagsmys'), findsOneWidget);
  });
}
