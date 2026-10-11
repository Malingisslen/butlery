import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/guest/guest_allergy_card.dart';
import 'package:butlery/widgets/guest/guest_band.dart';
import 'package:butlery/widgets/guest/guest_builder.dart';

/// The guest band and the allergy card at the top of Hem. It sits in the
/// scrolling header, so a large text size never pins it over the library.
class GuestHemIntro extends StatelessWidget {
  const GuestHemIntro({super.key});

  @override
  Widget build(BuildContext context) {
    return GuestBuilder(
      builder: (context, isGuest) {
        if (!isGuest) return const SizedBox.shrink();
        return const Padding(
          padding: EdgeInsets.fromLTRB(
            AppDimensions.spacingLg,
            AppDimensions.spacingSm,
            AppDimensions.spacingLg,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GuestBand(),
              SizedBox(height: AppDimensions.spacingSm),
              GuestAllergyCard(),
            ],
          ),
        );
      },
    );
  }
}
