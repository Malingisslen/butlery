import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/list/section_band.dart';
import 'package:flutter/material.dart';

class CollaborativeSectionHeader extends StatelessWidget {
  final String text;
  final int count;

  const CollaborativeSectionHeader({
    super.key,
    required this.text,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.space12),
      child: SectionBand(title: text, count: '$count'),
    );
  }
}
