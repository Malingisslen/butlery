/// BUT-907: the trash is part of what the content module registers, so the
/// trash screen can resolve it once the app has started.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/modules/content_module.dart';
import 'package:butlery/repositories/interfaces/trash_repository.dart';
import 'package:butlery/services/trash/trash_service.dart';

void main() {
  test(
    'configure registers the trash repository and the trash service',
    () async {
      final container = GetIt.asNewInstance();
      addTearDown(container.reset);

      await ContentModule().configure(container);

      expect(container.isRegistered<TrashRepository>(), isTrue);
      expect(container.isRegistered<TrashService>(), isTrue);
    },
  );
}
