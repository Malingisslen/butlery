import 'package:flutter/widgets.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/guest/guest_import_session.dart';
import 'package:butlery/widgets/guest/guest_account_sheet.dart';

/// Opens the "Du har använt dina tre importer" sheet when the server refuses a
/// guest's import for the limit. The exception is turned into a message
/// several layers below the import screens, so they hear it from the session.
class GuestImportLimitListener extends StatefulWidget {
  const GuestImportLimitListener({required this.child, super.key});

  final Widget child;

  @override
  State<GuestImportLimitListener> createState() =>
      _GuestImportLimitListenerState();
}

class _GuestImportLimitListenerState extends State<GuestImportLimitListener> {
  GuestImportSession? _session;

  @override
  void initState() {
    super.initState();
    _session = ServiceLocator.tryGet<GuestImportSession>()
      ?..limitHits.addListener(_onLimit);
  }

  @override
  void dispose() {
    _session?.limitHits.removeListener(_onLimit);
    super.dispose();
  }

  void _onLimit() {
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
    showGuestAccountSheet(context, GuestAccountReason.importLimit);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
