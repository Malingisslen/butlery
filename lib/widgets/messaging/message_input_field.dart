// lib/widgets/messaging/message_input_field.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/styled/styled_input.dart';

/// Styled text input field for messages
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
    return StyledInput.multiline(
      controller: controller,
      focusNode: focusNode,
      maxLines: 5,
      minLines: 1,
      hint: hintText,
      // DO NOT call onSubmitted on onChanged - that sends on every keystroke!
      // onSubmitted should only be called when user presses send button or Enter
    );
  }
}