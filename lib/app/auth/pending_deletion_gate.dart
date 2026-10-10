import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/account/account_deletion_service.dart';
import 'package:butlery/views/account/pending_deletion_view.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

/// Holds a signed-in user on [PendingDeletionView] while the account is
/// scheduled for deletion (BUT-950), and lets [builder] draw the app otherwise.
///
/// The token is read once per sign-in. The wrapper keys this gate by uid, so a
/// different user gets a fresh read. Cancelling reopens the app without
/// reading again: the service has refreshed the token by then.
class PendingDeletionGate extends StatefulWidget {
  const PendingDeletionGate({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  State<PendingDeletionGate> createState() => _PendingDeletionGateState();
}

class _PendingDeletionGateState extends State<PendingDeletionGate> {
  late final Future<DateTime?> _scheduledFor;
  bool _undone = false;

  @override
  void initState() {
    super.initState();
    _scheduledFor = ServiceLocator.get<AccountDeletionService>()
        .scheduledDeletionAt();
  }

  @override
  Widget build(BuildContext context) {
    if (_undone) return widget.builder(context);
    return FutureBuilder<DateTime?>(
      future: _scheduledFor,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          // Plate line plus text, never a spinner.
          return Scaffold(
            body: Center(
              child: PlateLineMessage(message: context.l10n.loadingProfileBusy),
            ),
          );
        }
        final date = snap.data;
        if (date == null) return widget.builder(context);
        return PendingDeletionView(
          scheduledFor: date,
          onUndone: () => setState(() => _undone = true),
        );
      },
    );
  }
}
