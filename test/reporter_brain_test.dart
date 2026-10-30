// The reporter's brain: understanding what was said and deciding what (if
// anything) to ask. Pure Dart, no server, no microphone.
// Run with:  flutter test test/reporter_brain_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:wingman/core/incidents/taxonomy.dart';
import 'package:wingman/core/models/analyze_result.dart';
import 'package:wingman/features/reporter/brain/conversation_brain.dart';
import 'package:wingman/features/reporter/brain/understanding.dart';

BrainTurn say(String text) => BrainTurn(slot: null, text: text);
BrainTurn answer(String slot, String text) => BrainTurn(slot: slot, text: text);

/// Runs a whole conversation the way the controller does: assess, ask the
/// next question (mark it as asked), take the scripted answer, repeat.
class Conversation {
  Conversation(String first, {this.maxQuestions = 3, this.server}) {
    turns.add(say(first));
  }

  final int maxQuestions;
  final AnalyzeResult? server;
  final ConversationBrain brain = ConversationBrain();
  final List<BrainTurn> turns = <BrainTurn>[];
  final List<String> asked = <String>[];
  late Assessment last;

  /// Plays [answers] in order, one per question asked. Returns the slots asked.
  List<String> run(List<String> answers) {
    var index = 0;
    for (var guard = 0; guard < 10; guard++) {
      last = brain.assess(
        turns: turns,
        server: server,
        maxQuestions: maxQuestions,
      );
      final next = last.next;
      if (next == null) break;
      brain.markAsked(next.slot);
      asked.add(next.slot);
      final reply = index < answers.length ? answers[index] : 'nu știu';
      index++;
      turns.add(answer(next.slot, reply));
    }
    return asked;
  }
}

void main() {
  group('understanding what was said', () {
    test('type from Romanian, with and without diacritics', () {
      expect(understand('Am o pată de ulei lângă avion').type?.code, 'SF-SPILL');
      expect(understand('am o pata de ulei langa avion').type?.code, 'SF-SPILL');
      expect(understand('Este fum în terminal').type?.code, 'SF-FIRE');
      expect(understand('Bagaj abandonat la intrare').type?.code, 'SC-BAG');
      expect(understand('Banda de bagaje s-a oprit').type?.code, 'MT-BELT');
      expect(understand('Liftul este blocat').type?.code, 'MT-ESC');
      expect(understand('Pasarela de îmbarcare nu merge').type?.code, 'MT-JBRIDGE');
    });

    test('type from English', () {
      expect(understand('There is an oil spill near gate 12').type?.code,
          'SF-SPILL');
      expect(understand('Smoke in the departure hall').type?.code, 'SF-FIRE');
      expect(understand('An unattended suitcase').type?.code, 'SC-BAG');
    });

    test('type words and category words are accepted as an answer', () {
      expect(understand('scurgere').type?.code, 'SF-SPILL');
      expect(understand('incendiu').type?.code, 'SF-FIRE');
      final security = understand('securitate');
      expect(security.type, isNull);
      expect(security.category, IncidentCategory.security);
      expect(understand('o defecțiune').category, IncidentCategory.maintenance);
      expect(understand('operațiuni').category, IncidentCategory.operations);
    });

    test('unknown things stay unknown instead of being guessed', () {
      final nothing = understand('nu știu, ceva ciudat');
      expect(nothing.type, isNull);
      expect(nothing.category, isNull);
      expect(understand('').type, isNull);
    });

    test('locations: digits, number words, letters, plain places', () {
      expect(understand('la poarta 12').location, 'Poarta 12');
      expect(understand('lângă poarta doisprezece').location, 'Poarta 12');
      expect(understand('în sectorul trei').location, 'Sector 3');
      expect(understand('at gate B').location, 'Gate B');
      expect(understand('terminal 2, nivelul 1').location, 'Terminal 2');
      expect(understand('lângă T1').location, 'Terminal 1');
      expect(understand('pe pistă').location, 'Pistă');
      expect(understand('în hol').location, 'Hol');
      expect(understand('undeva').location, isEmpty);
    });

    test('size: words, measures and comparisons, kept as said', () {
      expect(understand('o pată mare de ulei').size, 'mare');
      expect(understand('foarte mare').size, 'foarte mare');
      expect(understand('cam 2 metri').size, '2 metri');
      expect(understand('cât o farfurie').size, 'cât o farfurie');
      expect(understand('It is quite big').size, 'quite big');
      expect(understand('o pată de ulei').size, isNull);
    });

    test('people in danger and how many', () {
      expect(understand('nu e nimeni rănit').people, 'Nu');
      expect(understand('sunt doi răniți').people, 'Da');
      expect(understand('someone is trapped').people, 'Da');
      expect(understand('trei persoane').count, 'trei persoane');
      expect(yesNoFromAnswer('da, sunt'), 'Da');
      expect(yesNoFromAnswer('nu'), 'Nu');
      expect(yesNoFromAnswer('poate'), isNull);
    });
  });

  group('asking only what is missing, once', () {
    test('spill: asks where, then how big — and nothing else', () {
      final c = Conversation('Am o pată de ulei');
      expect(c.run(<String>['la poarta 12', 'mare']),
          <String>['location', 'size']);
      expect(c.last.next, isNull);
      expect(c.last.result.fields.incidentCode, 'SF-SPILL');
      expect(c.last.result.fields.location, 'Poarta 12');
      expect(c.last.details, <String, String>{'size': 'mare'});
      expect(c.last.result.missing, isEmpty);
    });

    test('everything volunteered in the first sentence: no questions', () {
      final c = Conversation('Pată mare de ulei la poarta 12');
      expect(c.run(const <String>[]), isEmpty);
      expect(c.last.details['size'], 'mare');
    });

    test('several answers in one go are all used', () {
      final c = Conversation('Am o pată de ulei');
      expect(c.run(<String>['la poarta 3, cât o masă']), <String>['location']);
      expect(c.last.details['size'], 'cât o masă');
    });

    test('fire: asks where, then whether anyone is in danger', () {
      final c = Conversation('Este fum');
      expect(c.run(<String>['terminal 2', 'nu e nimeni']),
          <String>['location', 'people']);
      expect(c.last.details['people'], 'Nu');
    });

    test('a bag needs no extra details', () {
      final c = Conversation('Bagaj abandonat la poarta 5');
      expect(c.run(const <String>[]), isEmpty);
    });
  });

  group('the bug: never ask the type again', () {
    test('unknown type: asks the type ONCE, accepts "scurgere"', () {
      final c = Conversation('Ceva nu e în regulă la poarta 3');
      final asked = c.run(<String>['scurgere', 'mare']);
      expect(asked.where((slot) => slot == 'type'), hasLength(1));
      expect(asked, <String>['type', 'size']);
      expect(c.last.result.fields.incidentCode, 'SF-SPILL');
    });

    test('an answer that matches nothing is recorded, not asked again', () {
      final c = Conversation('Ceva nu e în regulă la poarta 3');
      final asked = c.run(<String>['nu prea știu, e ciudat']);
      expect(asked, <String>['type']);
      expect(c.last.next, isNull);
      expect(c.last.result.fields.incidentCode, isNull);
      expect(c.last.result.fields.labelRo, contains('nu prea știu'));
      expect(c.last.result.missing, contains('incident_code'));
    });

    test('a category word is enough: "securitate" ends the type question', () {
      final c = Conversation('Ceva nu e în regulă la poarta 3');
      expect(c.run(<String>['securitate']), <String>['type']);
      expect(c.last.result.fields.labelRo, 'Securitate');
      expect(c.last.result.missing, isNot(contains('incident_code')));
    });

    test('an unparseable place is kept as said and never asked twice', () {
      final c = Conversation('Am o pată de ulei, mare');
      final asked = c.run(<String>['lângă gura de ventilație']);
      expect(asked, <String>['location']);
      expect(c.last.result.fields.location, 'lângă gura de ventilație');
    });

    test('no slot is ever asked twice, whatever the answers are', () {
      final c = Conversation('Ceva s-a întâmplat');
      final asked = c.run(<String>['nu știu', 'nu știu', 'nu știu', 'nu știu']);
      expect(asked.toSet().length, asked.length);
    });

    test('the question cap is respected', () {
      final c = Conversation('Ceva s-a întâmplat', maxQuestions: 1);
      expect(c.run(const <String>[]), hasLength(1));
      expect(c.last.next, isNull);
    });
  });

  group('with a server answer', () {
    AnalyzeResult serverKnows({String? code, String location = ''}) =>
        AnalyzeResult(
          fields: AnalyzeFields(
            incidentCode: code,
            labelRo: code == null ? null : IncidentTaxonomy.byCode(code)?.labelRo,
            location: location,
            urgency: Urgency.critical,
            confidence: 0.91,
          ),
          ready: true,
        );

    test('the server type wins; a ready server means no local questions', () {
      final c = Conversation(
        'ceva s-a vărsat',
        server: serverKnows(code: 'SF-SPILL', location: 'Poarta 12'),
      );
      // The server already extracted everything; the app must not ask the local
      // "size" detail after a complete report.
      expect(c.run(<String>['mare']), isEmpty);
      expect(c.last.result.fields.incidentCode, 'SF-SPILL');
      expect(c.last.result.fields.confidence, 0.91);
      expect(c.last.result.fields.urgency, Urgency.critical);
    });

    test('if the server cannot classify but the words are clear, no question',
        () {
      final c = Conversation('pată mare de ulei la poarta 12',
          server: serverKnows());
      expect(c.run(const <String>[]), isEmpty);
      expect(c.last.result.fields.incidentCode, 'SF-SPILL');
    });

    test('a question only the server knows is asked once', () {
      const odd = AnalyzeResult(
        fields: AnalyzeFields(incidentCode: 'SC-BAG', location: 'Poarta 5'),
        question: 'Bagajul are etichetă?',
      );
      final c = Conversation('bagaj abandonat', server: odd);
      expect(c.run(<String>['da']), <String>['server']);
    });

    test('hint code from the menu wins and is fully trusted', () {
      final brain = ConversationBrain();
      final assessment = brain.assess(
        turns: <BrainTurn>[say('ceva pe pistă'), answer('type', 'nu știu')],
        server: null,
        hintCode: 'SC-BEHAV',
      );
      expect(assessment.result.fields.incidentCode, 'SC-BEHAV');
      expect(assessment.result.fields.confidence, 1.0);
    });
  });
}
