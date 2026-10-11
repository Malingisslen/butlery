/// BUT-2353: the decisions list resolves its ViewModel through the container
/// (`ServiceLocator.get<MyContentDecisionsViewModel>()`), so losing the
/// registration turns "Beslut om mitt innehåll" into a crash on open while
/// every view test, which registers its own, stays green. Resolves nothing:
/// the entry is a factory, so no Firebase is needed.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/modules/ui_module.dart';
import 'package:butlery/viewmodels/settings/my_content_decisions_viewmodel.dart';

void main() {
  late GetIt container;

  setUp(() {
    container = GetIt.asNewInstance();
  });

  tearDown(() async {
    await container.reset();
  });

  test(
    'UIModule registers MyContentDecisionsViewModel and declares it',
    () async {
      await UIModule().configure(container);

      expect(container.isRegistered<MyContentDecisionsViewModel>(), isTrue);
      expect(UIModule().provides, contains(MyContentDecisionsViewModel));
    },
  );
}
