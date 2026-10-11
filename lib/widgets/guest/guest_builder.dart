import 'package:flutter/widgets.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/guest/guest_status.dart';

/// Builds with whether the current user is a guest, and rebuilds when the
/// auth state changes. Without an auth service (a test host) nobody is a guest.
class GuestBuilder extends StatefulWidget {
  const GuestBuilder({required this.builder, super.key});

  final Widget Function(BuildContext context, bool isGuest) builder;

  @override
  State<GuestBuilder> createState() => _GuestBuilderState();
}

class _GuestBuilderState extends State<GuestBuilder> {
  AuthService? _auth;

  @override
  void initState() {
    super.initState();
    _auth = ServiceLocator.tryGet<AuthService>();
  }

  @override
  Widget build(BuildContext context) {
    final auth = _auth;
    if (auth == null) return widget.builder(context, false);
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) => widget.builder(context, auth.isGuest),
    );
  }
}
