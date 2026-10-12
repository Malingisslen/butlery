import 'package:flutter/foundation.dart';

/// True from the moment the onboarding write starts until the user has seen
/// the last onboarding screen. The write flips the profile to "onboarded", and
/// without this hold the app would swap the wizard for Hem under the setup
/// screen.
class OnboardingHold {
  OnboardingHold._();

  static final ValueNotifier<bool> active = ValueNotifier<bool>(false);
}
