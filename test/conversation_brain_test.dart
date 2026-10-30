// The reporter conversation must never re-ask what the server already knows.
// Real bug this locks in: "o femeie a luat foc la poarta 2" (complete report)
// still triggered extra local questions because the local brain wanted a
// "people" detail even though the server marked the report ready.
import 'package:flutter_test/flutter_test.dart';
import 'package:wingman/core/incidents/taxonomy.dart';
import 'package:wingman/core/models/analyze_result.dart';
import 'package:wingman/core/models/ticket.dart';
import 'package:wingman/features/reporter/brain/conversation_brain.dart';

AnalyzeResult _serverComplete() => const AnalyzeResult(
      fields: AnalyzeFields(
        incidentCode: 'SF-FIRE',
        labelRo: 'Foc sau fum în terminal',
        location: 'Poarta 2',
        peopleAtRisk: true,
        urgency: Urgency.critical,
        confidence: 0.9,
        aiSource: AiSource.ollama,
      ),
      ready: true,
    );

AnalyzeResult _serverAsksPeople() => const AnalyzeResult(
      fields: AnalyzeFields(
        incidentCode: 'SF-FIRE',
        labelRo: 'Foc sau fum în terminal',
        location: 'Poarta 2',
        urgency: Urgency.critical,
        confidence: 0.9,
        aiSource: AiSource.ollama,
      ),
      question: 'Este cineva în pericol în acest moment?',
      ready: false,
    );

AnalyzeResult _serverAsksLocation() => const AnalyzeResult(
      fields: AnalyzeFields(
        incidentCode: 'SF-FIRE',
        labelRo: 'Foc sau fum în terminal',
        urgency: Urgency.critical,
        confidence: 0.9,
        aiSource: AiSource.ollama,
      ),
      missing: <String>['location'],
      question: 'Unde se întâmplă exact? (terminal, poartă sau zonă)',
      ready: false,
    );

void main() {
  const spoken = 'o femeie a luat foc la poarta 2';

  test('server-complete report → no questions at all', () {
    final brain = ConversationBrain();
    final assessment = brain.assess(
      turns: const <BrainTurn>[BrainTurn(slot: null, text: spoken)],
      server: _serverComplete(),
    );
    expect(assessment.next, isNull);
    expect(assessment.result.ready, isTrue);
    expect(assessment.result.fields.location, 'Poarta 2');
    expect(assessment.result.fields.peopleAtRisk, isTrue);
  });

  test('server says ready even though local brain lacks the people detail', () {
    // SF-FIRE declares a "people" detail slot locally; before the fix this made
    // the app ask "Este cineva în pericol?" after the server had already said
    // the report was complete.
    final brain = ConversationBrain();
    final assessment = brain.assess(
      turns: const <BrainTurn>[BrainTurn(slot: null, text: spoken)],
      server: _serverComplete(),
      english: false,
    );
    expect(assessment.next, isNull);
  });

  test('server asking for people → app asks the people question', () {
    final brain = ConversationBrain();
    final assessment = brain.assess(
      turns: const <BrainTurn>[BrainTurn(slot: null, text: spoken)],
      server: _serverAsksPeople(),
    );
    expect(assessment.next?.slot, 'people');
  });

  test('server asking for location → app asks the location question', () {
    final brain = ConversationBrain();
    final assessment = brain.assess(
      turns: const <BrainTurn>[BrainTurn(slot: null, text: spoken)],
      server: _serverAsksLocation(),
    );
    expect(assessment.next?.slot, 'location');
  });

  test('offline: local understanding still extracts location + danger', () {
    final brain = ConversationBrain();
    final assessment = brain.assess(
      turns: const <BrainTurn>[BrainTurn(slot: null, text: spoken)],
      server: null, // server unreachable → local fallback
    );
    expect(assessment.result.fields.location, 'Poarta 2');
    expect(assessment.details['people'], 'Da');
    expect(assessment.next, isNull);
  });

  test('offline without a place still asks for the place', () {
    final brain = ConversationBrain();
    final assessment = brain.assess(
      turns: const <BrainTurn>[BrainTurn(slot: null, text: 'o femeie a luat foc')],
      server: null,
    );
    expect(assessment.next?.slot, 'location');
    expect(assessment.details['people'], 'Da');
  });
}
