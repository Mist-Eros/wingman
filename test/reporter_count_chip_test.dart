import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wingman/core/models/ticket.dart';
import 'package:wingman/core/widgets/reporter_count_chip.dart';

import 'core_contract_test.dart' show sampleTicketJson;

void main() {
  testWidgets('shows the number of distinct reporters with a people icon',
      (tester) async {
    final ticket = Ticket.fromJson(sampleTicketJson());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReporterCountChip(ticket: ticket),
        ),
      ),
    );

    expect(find.byIcon(Icons.people_alt_outlined), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(
      find.byTooltip('2 raportări · 2 persoane'),
      findsOneWidget,
    );
  });
}
