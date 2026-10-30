// The sky look must follow the local clock: morning/noon/evening/night, plus a
// deterministic override for demo screenshots (`--dart-define=SKY_PERIOD=...`).
import 'package:flutter_test/flutter_test.dart';
import 'package:wingman/core/widgets/sky_background.dart';

void main() {
  test('maps local hours to the six looks', () {
    expect(SkyPeriod.forHour(5), SkyPeriod.dawn);
    expect(SkyPeriod.forHour(6), SkyPeriod.dawn);
    expect(SkyPeriod.forHour(7), SkyPeriod.morning);
    expect(SkyPeriod.forHour(10), SkyPeriod.morning);
    expect(SkyPeriod.forHour(11), SkyPeriod.midday);
    expect(SkyPeriod.forHour(15), SkyPeriod.midday);
    expect(SkyPeriod.forHour(16), SkyPeriod.afternoon);
    expect(SkyPeriod.forHour(17), SkyPeriod.afternoon);
    expect(SkyPeriod.forHour(18), SkyPeriod.sunset);
    expect(SkyPeriod.forHour(19), SkyPeriod.sunset);
    expect(SkyPeriod.forHour(20), SkyPeriod.night);
    expect(SkyPeriod.forHour(23), SkyPeriod.night);
    expect(SkyPeriod.forHour(0), SkyPeriod.night);
    expect(SkyPeriod.forHour(4), SkyPeriod.night);
  });

  test('every look has a 4-stop palette and a Romanian label', () {
    for (final period in SkyPeriod.values) {
      expect(period.skyColors.length, 4, reason: period.name);
      expect(period.labelRo, isNotEmpty, reason: period.name);
    }
  });

  test('night is dark and midday is bright', () {
    expect(SkyPeriod.night.skyColors.first.computeLuminance(), lessThan(0.05));
    expect(
      SkyPeriod.midday.skyColors.last.computeLuminance(),
      greaterThan(0.5),
    );
  });

  test('night and dawn show stars; only night is night', () {
    expect(SkyPeriod.night.hasStars, isTrue);
    expect(SkyPeriod.dawn.hasStars, isTrue);
    expect(SkyPeriod.midday.hasStars, isFalse);
    expect(SkyPeriod.night.isNight, isTrue);
    expect(SkyPeriod.sunset.isNight, isFalse);
  });
}
