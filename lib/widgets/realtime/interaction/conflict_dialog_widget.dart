import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Dialog för att hantera konflikter vid realtidsredigering
class ConflictDialogWidget extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onResolve;

  const ConflictDialogWidget({
    super.key,
    required this.title,
    required this.message,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title, style: AppTheme.cardTitleStyle),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Avbryt'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onResolve();
          },
          child: const Text('Lös konflikt'),
        ),
      ],
    );
  }
}
