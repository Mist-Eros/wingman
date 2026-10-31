// Accessibility profiles for airport staff. The settings are intentionally
// global (session-level) so every screen — login, reporter, dispatcher, crew —
// respects them without each feature having to re-implement them.

import 'package:flutter/foundation.dart';

enum AccessibilityProfile {
  none('Fără profil'),
  blind('Orb / vedere redusă'),
  mute('Mut / fără voce'),
  deaf('Surd / hipoacuzic'),
  colorblind('Daltonist'),
  motor('Mobilitate redusă'),
  cognitive('Cognitiv / neurodivergent');

  const AccessibilityProfile(this.labelRo);
  final String labelRo;
}

class AccessibilitySettings extends ChangeNotifier {
  AccessibilitySettings._();
  static final AccessibilitySettings instance = AccessibilitySettings._();

  AccessibilityProfile profile = AccessibilityProfile.none;

  /// 1.0 = normal, 1.25 = large, 1.5 = extra large.
  double textScale = 1.0;

  bool highContrast = false;
  bool colorBlindSafe = false;
  bool visualAlerts = false;
  bool spokenGuidance = false;
  bool typedFirst = false;
  bool largeTargets = false;
  bool simplifiedLanguage = false;

  // Backwards-friendly aliases for the rest of the app.
  bool get textLarge => textScale >= 1.2;

  void applyProfile(AccessibilityProfile next) {
    profile = next;
    switch (next) {
      case AccessibilityProfile.none:
        textScale = 1.0;
        highContrast = false;
        colorBlindSafe = false;
        visualAlerts = false;
        spokenGuidance = false;
        typedFirst = false;
        largeTargets = false;
        simplifiedLanguage = false;
      case AccessibilityProfile.blind:
        textScale = 1.35;
        highContrast = true;
        visualAlerts = false;
        spokenGuidance = true;
        typedFirst = false;
        largeTargets = true;
        simplifiedLanguage = false;
      case AccessibilityProfile.mute:
        textScale = 1.15;
        highContrast = true;
        visualAlerts = true;
        spokenGuidance = false;
        typedFirst = true;
        largeTargets = true;
        simplifiedLanguage = false;
      case AccessibilityProfile.deaf:
        textScale = 1.15;
        highContrast = true;
        visualAlerts = true;
        spokenGuidance = false;
        typedFirst = false;
        largeTargets = true;
        simplifiedLanguage = false;
      case AccessibilityProfile.colorblind:
        textScale = 1.0;
        highContrast = true;
        colorBlindSafe = true;
        visualAlerts = false;
        spokenGuidance = false;
        typedFirst = false;
        largeTargets = false;
        simplifiedLanguage = false;
      case AccessibilityProfile.motor:
        textScale = 1.15;
        highContrast = false;
        colorBlindSafe = false;
        visualAlerts = false;
        spokenGuidance = false;
        typedFirst = false;
        largeTargets = true;
        simplifiedLanguage = false;
      case AccessibilityProfile.cognitive:
        textScale = 1.2;
        highContrast = false;
        colorBlindSafe = false;
        visualAlerts = false;
        spokenGuidance = false;
        typedFirst = false;
        largeTargets = true;
        simplifiedLanguage = true;
    }
    notifyListeners();
  }

  void setTextScale(double value) {
    textScale = value;
    profile = AccessibilityProfile.none;
    notifyListeners();
  }

  void setFlag(
    String key,
    bool value,
  ) {
    switch (key) {
      case 'highContrast':
        highContrast = value;
      case 'colorBlindSafe':
        colorBlindSafe = value;
      case 'visualAlerts':
        visualAlerts = value;
      case 'spokenGuidance':
        spokenGuidance = value;
      case 'typedFirst':
        typedFirst = value;
      case 'largeTargets':
        largeTargets = value;
      case 'simplifiedLanguage':
        simplifiedLanguage = value;
    }
    profile = AccessibilityProfile.none;
    notifyListeners();
  }

  void reset() => applyProfile(AccessibilityProfile.none);
}
