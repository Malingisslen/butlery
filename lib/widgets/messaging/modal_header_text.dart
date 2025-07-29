// lib/widgets/messaging/modal_header_text.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Styled header text for modal content
class ModalHeaderText extends StatelessWidget {
  final String text;

  const ModalHeaderText(
    this.text, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          text,
          style: AppTextStyles.headlineSmall.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppDimensions.paddingL),
      ],
    );
  }
}