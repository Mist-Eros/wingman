// Real airport scenarios, end to end through the reporter's brain (no server):
// what type is recognized, how URGENT it is graded and where it happened.
// A failing row means the brain misunderstood a sentence a reporter could say.
//
// Run with:  flutter test test/reporter_scenarios_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:wingman/core/incidents/taxonomy.dart';
import 'package:wingman/core/models/analyze_result.dart';
import 'package:wingman/features/reporter/brain/conversation_brain.dart';

/// A server reply that already classified the report.
class AnalyzeResultFactory {
  static AnalyzeResult spill({required Urgency urgency}) => AnalyzeResult(
        fields: AnalyzeFields(
          incidentCode: 'SF-SPILL',
          labelRo: IncidentTaxonomy.byCode('SF-SPILL')!.labelRo,
          urgency: urgency,
          confidence: 0.88,
        ),
        ready: true,
      );
}

class Scenario {
  const Scenario(
    this.said, {
    this.code,
    required this.urgency,
    this.place,
    this.category,
  });

  final String said;

  /// Expected taxonomy code (null = must stay unknown).
  final String? code;
  final Urgency urgency;

  /// Expected location, or null when none is said.
  final String? place;
  final IncidentCategory? category;
}

const L = Urgency.low;
const M = Urgency.medium;
const H = Urgency.high;
const C = Urgency.critical;

const List<Scenario> scenarios = <Scenario>[
  // ── the case that exposed the problem ──────────────────────────────────────
  Scenario('Lava curge în terminalul 3',
      code: 'SF-FIRE', urgency: C, place: 'Terminal 3'),
  Scenario('There is lava flowing in terminal 3',
      code: 'SF-FIRE', urgency: C, place: 'Terminal 3'),

  // ── safety & fire ──────────────────────────────────────────────────────────
  Scenario('Fum gros în terminalul 2',
      code: 'SF-FIRE', urgency: C, place: 'Terminal 2'),
  Scenario('Miros de ars la ghișeul 14',
      code: 'SF-FIRE', urgency: C, place: 'Ghișeu 14'),
  Scenario('Alarma de incendiu a sunat la poarta 6',
      code: 'SF-FIRE', urgency: C, place: 'Poarta 6'),
  Scenario('Fire alarm going off in terminal 2',
      code: 'SF-FIRE', urgency: C, place: 'Terminal 2'),
  Scenario('Gas smell near gate 7',
      code: 'SF-FIRE', urgency: C, place: 'Gate 7'),
  Scenario('Miros de gaz la nivelul 1',
      code: 'SF-FIRE', urgency: C, place: 'Nivel 1'),
  Scenario('Un power bank a luat foc în sala de așteptare',
      code: 'SF-FIRE', urgency: C),
  Scenario('Scântei la priza de lângă poarta 4',
      code: 'SF-FIRE', urgency: C, place: 'Poarta 4'),
  Scenario('A explodat ceva la poarta 9',
      code: 'SF-FIRE', urgency: C, place: 'Poarta 9'),

  // spills: the urgency depends on WHAT and WHERE, not only on the type
  Scenario('Pată mică de apă în hol',
      code: 'SF-SPILL', urgency: M, place: 'Hol'),
  Scenario('Cafea vărsată lângă poarta 12',
      code: 'SF-SPILL', urgency: M, place: 'Poarta 12'),
  Scenario('Puddle of coffee near gate A',
      code: 'SF-SPILL', urgency: M, place: 'Gate A'),
  Scenario('Țeavă spartă, apă pe jos la nivelul 1',
      code: 'SF-SPILL', urgency: M, place: 'Nivel 1'),
  Scenario('Ice on the walkway in front of terminal 1',
      code: 'SF-SPILL', urgency: M, place: 'Terminal 1'),
  Scenario('Pată mare de ulei în terminalul 2',
      code: 'SF-SPILL', urgency: H, place: 'Terminal 2'),
  Scenario('Podea udă, cineva a alunecat la poarta 3',
      code: 'SF-SPILL', urgency: H, place: 'Poarta 3'),
  Scenario('Am o pată de ulei lângă avion la poarta 5',
      code: 'SF-SPILL', urgency: H, place: 'Poarta 5'),
  Scenario('Scurgere de ulei pe pista 2, foarte mare',
      code: 'SF-SPILL', urgency: C, place: 'Pista 2'),
  Scenario('Scurgere mare de combustibil sub avion pe platformă',
      code: 'SF-SPILL', urgency: C, place: 'Platformă'),
  Scenario('Kerosene leak under the aircraft at stand 14, it is spreading',
      code: 'SF-SPILL', urgency: C, place: 'Stand 14'),
  Scenario('Inundație în toaleta de la terminalul 1',
      code: 'SF-SPILL', urgency: M, place: 'Terminal 1'),

  Scenario('Șurub pe pistă', code: 'SF-FOD', urgency: C, place: 'Pistă 09/27'),
  Scenario('Bird on the runway',
      code: 'SF-FOD', urgency: C, place: 'Pistă 09/27'),
  Scenario('Un câine pe platformă',
      code: 'SF-FOD', urgency: C, place: 'Platformă'),
  Scenario('Foreign object near stand 9',
      code: 'SF-FOD', urgency: C, place: 'Stand 9'),

  Scenario('Extinctor lipsă lângă poarta 4',
      code: 'SF-EQUIP', urgency: H, place: 'Poarta 4'),
  Scenario('Ieșirea de urgență este blocată la terminalul 1',
      code: 'SF-EQUIP', urgency: H, place: 'Terminal 1'),
  Scenario('The smoke detector is broken at gate 3',
      code: 'SF-EQUIP', urgency: H, place: 'Gate 3'),

  // ── security ───────────────────────────────────────────────────────────────
  Scenario('Bagaj abandonat la poarta 5',
      code: 'SC-BAG', urgency: H, place: 'Poarta 5'),
  Scenario('Unattended suitcase at gate B',
      code: 'SC-BAG', urgency: H, place: 'Gate B'),
  Scenario('O geantă uitată în sala de plecări',
      code: 'SC-BAG', urgency: H, place: 'Terminal Plecări'),
  Scenario('Cineva a sărit gardul lângă pista 2',
      code: 'SC-ACCESS', urgency: C, place: 'Pista 2'),
  Scenario('Pasager pe platformă',
      code: 'SC-ACCESS', urgency: C, place: 'Platformă'),
  Scenario('Drone over the terminal',
      code: 'SC-ACCESS', urgency: C, place: 'Terminal'),
  Scenario('Cuțit găsit în bagajul de mână', code: 'SC-ITEM', urgency: H),
  Scenario('Bomb threat at gate 3',
      code: 'SC-ITEM', urgency: C, place: 'Gate 3'),
  Scenario('Doi bărbați se bat în terminalul 1',
      code: 'SC-BEHAV', urgency: H, place: 'Terminal 1'),
  Scenario('Drunk man shouting at gate 3',
      code: 'SC-BEHAV', urgency: H, place: 'Gate 3'),
  Scenario('Cineva fumează în zona de îmbarcare',
      code: 'SC-BEHAV', urgency: H, place: 'Zona de îmbarcare'),

  // ── maintenance ────────────────────────────────────────────────────────────
  Scenario('Banda de bagaje 3 s-a oprit',
      code: 'MT-BELT', urgency: H, place: 'Banda 3'),
  Scenario('Luggage is not coming out of the carousel',
      code: 'MT-BELT', urgency: H),
  Scenario('Escalatorul este stricat la nivelul 2',
      code: 'MT-ESC', urgency: M, place: 'Nivel 2'),
  Scenario('Elevator stuck with people inside', code: 'MT-ESC', urgency: H),
  Scenario('Cineva a căzut pe scările rulante', code: 'MT-ESC', urgency: H),
  Scenario('Pasarela de îmbarcare de la poarta 8 nu se mișcă',
      code: 'MT-JBRIDGE', urgency: H, place: 'Poarta 8'),
  Scenario('Ușa automată nu se deschide la intrarea B',
      code: 'MT-ESC', urgency: M, place: 'Intrarea principală'),

  // ── operations ─────────────────────────────────────────────────────────────
  Scenario('Coadă uriașă la controlul de securitate',
      code: 'OP-QUEUE', urgency: M, place: 'Control securitate'),
  Scenario('Prea mulți oameni la poarta 10',
      code: 'OP-QUEUE', urgency: M, place: 'Poarta 10'),
  Scenario('Sistemul de check-in a căzut', code: 'OP-IT', urgency: H),
  Scenario('Flight information display is not working',
      code: 'OP-IT', urgency: H),
  Scenario('Radio communication is down at the apron',
      code: 'OP-IT', urgency: C, place: 'Platformă'),

  // ── life at risk: always critical, even without a dedicated type ───────────
  Scenario('Cineva a leșinat la poarta 6',
      code: 'OP-OTHER', urgency: C, place: 'Poarta 6'),
  Scenario('Someone is not breathing in the departure hall',
      code: 'OP-OTHER', urgency: C),
  Scenario('Un pasager a făcut infarct la terminalul 2',
      code: 'OP-OTHER', urgency: C, place: 'Terminal 2'),

  // ── only the category is known, or nothing ─────────────────────────────────
  Scenario('Este o problemă de securitate la poarta 3',
      urgency: H, place: 'Poarta 3', category: IncidentCategory.security),
  Scenario('Ceva ciudat', urgency: M),
];

void main() {
  group('scenarios: type, urgency and place', () {
    for (final s in scenarios) {
      test(s.said, () {
        final brain = ConversationBrain();
        final fields = brain
            .assess(
              turns: <BrainTurn>[BrainTurn(slot: null, text: s.said)],
              server: null,
            )
            .result
            .fields;
        expect(fields.incidentCode, s.code, reason: 'type of "${s.said}"');
        expect(fields.urgency, s.urgency,
            reason: 'urgency of "${s.said}": ${fields.rationale}');
        expect(fields.location, s.place ?? '', reason: 'place of "${s.said}"');
        if (s.category != null) {
          final category =
              IncidentTaxonomy.byCode(fields.incidentCode ?? '')?.category ??
                  (fields.labelRo == s.category!.labelRo ? s.category : null);
          expect(category, s.category);
        }
      });
    }
  });

  group('the lava case, explained', () {
    Assessment lava({bool english = false}) => ConversationBrain().assess(
          turns: <BrainTurn>[
            BrainTurn(
              slot: null,
              text: english
                  ? 'There is lava flowing in terminal 3'
                  : 'Lava curge în terminalul 3',
            ),
          ],
          server: null,
          english: english,
        );

    test('critical, fire type, and the card says why', () {
      final fields = lava().result.fields;
      expect(fields.incidentCode, 'SF-FIRE');
      expect(fields.urgency, Urgency.critical);
      expect(fields.rationale, contains('pericol de foc sau explozie'));
      expect(fields.rationale, contains('Probabilitate Craiova'));
      expect(lava(english: true).result.fields.rationale,
          contains('fire or explosion hazard'));
    });

    test('it does not ask about people in danger — dispatch immediately', () {
      expect(lava().next, isNull);
      expect(lava().result.fields.incidentCode, 'SF-FIRE');
    });
  });

  group('urgency grows with what was said (never below the type)', () {
    Urgency urgencyOf(String said) => ConversationBrain()
        .assess(
          turns: <BrainTurn>[BrainTurn(slot: null, text: said)],
          server: null,
        )
        .result
        .fields
        .urgency;

    test('a slippery spill: small < big < next to an aircraft < fuel + huge',
        () {
      final levels = <int>[
        urgencyOf('mică pată de apă în hol').level,
        urgencyOf('mare pată de apă în hol').level,
        urgencyOf('pată de ulei lângă avion').level,
        urgencyOf('scurgere de combustibil foarte mare lângă avion').level,
      ];
      expect(levels, <int>[2, 3, 3, 4]);
    });

    test('someone in danger makes it at least high', () {
      expect(urgencyOf('liftul este blocat').level, 2);
      expect(urgencyOf('liftul este blocat, sunt oameni inăuntru').level, 3);
    });

    test('"urgent" and "it is spreading" each add a level', () {
      final base = urgencyOf('coadă la controlul de securitate').level;
      expect(urgencyOf('coadă la controlul de securitate, urgent').level,
          base + 1);
      expect(urgencyOf('coadă la controlul de securitate, se mărește').level,
          base + 1);
    });

    test('the server floor is respected, but what was said can still raise it',
        () {
      final server = AnalyzeResultFactory.spill(urgency: Urgency.high);
      final fields = ConversationBrain()
          .assess(
            turns: <BrainTurn>[
              BrainTurn(
                  slot: null, text: 'scurgere de combustibil lângă avion'),
            ],
            server: server,
          )
          .result
          .fields;
      expect(fields.urgency, Urgency.critical);
      expect(fields.confidence, 0.88); // the server's own number is kept
    });
  });

  group('confidence is computed, not guessed', () {
    double confidenceOf(String said, {String? answerType}) {
      final turns = <BrainTurn>[
        BrainTurn(slot: null, text: said),
        if (answerType != null) BrainTurn(slot: 'type', text: answerType),
      ];
      return ConversationBrain()
          .assess(turns: turns, server: null)
          .result
          .fields
          .confidence;
    }

    test('clear words + place + detail → high', () {
      expect(confidenceOf('pată mare de ulei la poarta 12'), greaterThan(0.78));
    });

    test('nothing recognizable → very low', () {
      expect(confidenceOf('ceva ciudat'), lessThanOrEqualTo(0.1));
    });

    test('a place raises it, a missing place lowers it', () {
      final withPlace = confidenceOf('fum la poarta 3');
      final without = confidenceOf('fum');
      expect(withPlace, greaterThan(without));
      expect(withPlace - without, closeTo(0.17, 0.001));
    });

    test('two competing readings give a lower number than a clear one', () {
      final clear = confidenceOf('scurgere de ulei la poarta 3');
      final vague = confidenceOf('lava curge la poarta 3');
      expect(vague, lessThan(clear));
    });

    test('a type the reporter stated is trusted', () {
      expect(
          confidenceOf('ceva nu e în regulă la poarta 3',
              answerType: 'scurgere'),
          greaterThanOrEqualTo(0.75));
    });

    test('never 1.0 unless picked from the menu; always within bounds', () {
      for (final s in scenarios) {
        final c = confidenceOf(s.said);
        expect(c, inInclusiveRange(0.05, 0.95), reason: s.said);
      }
    });
  });
}
