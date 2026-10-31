import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wingman/features/reporter/reporter_widgets.dart';

void main() {
  testWidgets('low-confidence words are underlined and editable only',
      (tester) async {
    final tapped = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TranscriptChips(
            words: const <String>['There', 'is', 'smoke', 'near', 'gate', '12'],
            confidences: const <double?>[
              0.88,
              0.99,
              0.76,
              0.99,
              0.55,
              0.98,
            ],
            onTap: tapped.add,
          ),
        ),
      ),
    );

    final gate = tester.widget<Text>(find.text('gate'));
    expect(gate.style?.decoration, TextDecoration.underline);

    final smoke = tester.widget<Text>(find.text('smoke'));
    expect(smoke.style?.decoration, isNot(TextDecoration.underline));

    await tester.tap(find.text('gate'));
    await tester.tap(find.text('smoke'));
    expect(tapped, <int>[4], reason: 'only the uncertain word is editable');
  });

  testWidgets('legacy words without confidence remain editable',
      (tester) async {
    final tapped = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TranscriptChips(
            words: const <String>['typed', 'text'],
            onTap: tapped.add,
          ),
        ),
      ),
    );
    await tester.tap(find.text('typed'));
    expect(tapped, <int>[0]);
  });
}
