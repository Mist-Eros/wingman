// Language handling for the reporter flow (Romanian + English).
//
// The server owns the slot logic and sends Romanian questions; the app only
// translates the two slots it knows about (see ReporterController). Everything
// else on the reporter screens is translated through [Tr].

enum ReporterLanguage {
  ro('RO', 'ro-RO'),
  en('EN', 'en-US');

  const ReporterLanguage(this.label, this.ttsTag);

  /// Short label for the toggle.
  final String label;

  /// BCP-47 tag used by text-to-speech.
  final String ttsTag;

  /// Language code used to pick a speech-recognition locale ("ro" / "en").
  String get code => name;
}

/// `tr('Română', 'English')` — picks the string for the current language.
class Tr {
  const Tr(this.language);

  final ReporterLanguage language;

  String call(String ro, String en) =>
      language == ReporterLanguage.ro ? ro : en;
}
