import 'package:flutter_test/flutter_test.dart';
import 'package:wingman/core/incidents/taxonomy.dart';
import 'package:wingman/features/reporter/menu/incident_menu_data.dart';

void main() {
  test('8x8x8 menu catalog is complete and maps to the closed taxonomy', () {
    expect(menuCategories.length, 8);
    expect(menuProblemCount, 512);

    final ids = <String>{};
    for (final category in menuCategories) {
      expect(category.subcategories.length, 8, reason: category.label);
      for (final subcategory in category.subcategories) {
        expect(subcategory.problems.length, 8, reason: subcategory.label);
        for (final problem in subcategory.problems) {
          expect(ids.add(problem.id), isTrue, reason: problem.id);
          expect(IncidentTaxonomy.byCode(problem.typeCode), isNotNull,
              reason: '${problem.id} -> ${problem.typeCode}');
          expect(problem.label.trim(), isNotEmpty);
          expect(problem.location.trim(), isNotEmpty);
        }
      }
    }
    expect(ids.length, 512);
  });
}
