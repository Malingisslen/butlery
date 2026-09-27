/// P8-U01: small pieces the hosts share.
library;

import 'package:flutter/material.dart';

/// A page that opens [open] once it is on screen, as the app opens a dialog
/// or a sheet over the view that asked for it.
class OpensOnMount extends StatefulWidget {
  const OpensOnMount({required this.open, required this.page, super.key});

  /// Opens the dialog or sheet over [page].
  final void Function(BuildContext context) open;

  /// The page under it.
  final Widget page;

  @override
  State<OpensOnMount> createState() => _OpensOnMountState();
}

class _OpensOnMountState extends State<OpensOnMount> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.open(context);
    });
  }

  @override
  Widget build(BuildContext context) => widget.page;
}
