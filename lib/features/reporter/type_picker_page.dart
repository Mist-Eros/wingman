// Waze-style button menu: pick a category, then the incident type. Works with
// no voice and no AI wait (the type is sent as `hint_code`).

import 'package:flutter/material.dart';

import '../../core/incidents/taxonomy.dart';
import 'reporter_language.dart';

class TypePickerPage extends StatefulWidget {
  const TypePickerPage({super.key, required this.language});

  final ReporterLanguage language;

  @override
  State<TypePickerPage> createState() => _TypePickerPageState();
}

class _TypePickerPageState extends State<TypePickerPage> {
  IncidentCategory? _category;

  Tr get _tr => Tr(widget.language);

  static const Map<IncidentCategory, IconData> _icons =
      <IncidentCategory, IconData>{
    IncidentCategory.safetyFire: Icons.local_fire_department,
    IncidentCategory.security: Icons.shield_outlined,
    IncidentCategory.maintenance: Icons.build_outlined,
    IncidentCategory.operations: Icons.flight_takeoff,
  };

  String _categoryLabel(IncidentCategory category) {
    if (widget.language == ReporterLanguage.ro) return category.labelRo;
    switch (category) {
      case IncidentCategory.safetyFire:
        return 'Safety & fire';
      case IncidentCategory.security:
        return 'Security';
      case IncidentCategory.maintenance:
        return 'Maintenance';
      case IncidentCategory.operations:
        return 'Operations';
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = _category;
    return PopScope(
      canPop: category == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _category = null);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            category == null
                ? _tr('Ce s-a întâmplat?', 'What happened?')
                : _categoryLabel(category),
          ),
        ),
        body: SafeArea(
          child: category == null ? _categories() : _types(category),
        ),
      ),
    );
  }

  Widget _categories() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        for (final category in IncidentCategory.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(76),
                alignment: Alignment.centerLeft,
                textStyle: Theme.of(context).textTheme.titleMedium,
              ),
              icon: Icon(_icons[category], size: 32),
              label: Text(_categoryLabel(category)),
              onPressed: () => setState(() => _category = category),
            ),
          ),
      ],
    );
  }

  Widget _types(IncidentCategory category) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        for (final type in IncidentTaxonomy.byCategory(category))
          Card(
            child: ListTile(
              minVerticalPadding: 14,
              title: Text(
                type.labelRo,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(
                '${type.code} · ${type.primaryDepartments.map((d) => d.labelRo).join(", ")}',
              ),
              trailing: Chip(
                label: Text(type.urgency.labelRo),
                backgroundColor: type.urgency.level >= Urgency.high.level
                    ? scheme.errorContainer
                    : scheme.surfaceContainerHighest,
              ),
              onTap: () => Navigator.of(context).pop(type),
            ),
          ),
      ],
    );
  }
}
