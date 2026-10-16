// lib/widgets/messaging/message_input_field.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/input/butlery_composer_field.dart';

/// The chat's message field.
class MessageInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final VoidCallback? onSubmitted;

  const MessageInputField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    // Enter makes a new line; the send button sends. onSubmitted is not
    // wired to onChanged, which would send on every keystroke.
    return ButleryComposerField(
      controller: controller,
      focusNode: focusNode,
      hintText: hintText,
    );
  }
}
