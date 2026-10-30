import 'package:flutter/material.dart';

import '../../core/incidents/taxonomy.dart';

/// Asks the dispatcher for a short deny reason. Returns null if cancelled.
Future<String?> showDenyReasonDialog(BuildContext context) async {
  final controller = TextEditingController();
  final reason = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Respinge tichetul'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Motiv',
              hintText: 'ex. fals pozitiv, clasificare greșită…',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              final trimmed = value.trim();
              if (trimmed.isNotEmpty) {
                Navigator.of(context).pop(trimmed);
              }
            },
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isEmpty) return;
              Navigator.of(context).pop(trimmed);
            },
            child: const Text('Respinge'),
          ),
        ],
      );
    },
  );
  controller.dispose();
  return reason?.trim().isEmpty == true ? null : reason?.trim();
}

/// Result of a reclassify pick.
class ReclassifyChoice {
  const ReclassifyChoice({required this.incidentCode, this.urgency});

  final String incidentCode;
  final Urgency? urgency;
}

/// Lists taxonomy codes for override. Returns null if cancelled.
Future<ReclassifyChoice?> showReclassifyDialog(BuildContext context) async {
  String? selectedCode = IncidentTaxonomy.all.first.code;
  Urgency? selectedUrgency;

  return showDialog<ReclassifyChoice>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setLocal) {
          final selected = IncidentTaxonomy.all.firstWhere(
            (t) => t.code == selectedCode,
            orElse: () => IncidentTaxonomy.all.first,
          );

          return AlertDialog(
            title: const Text('Reclasifică incidentul'),
            content: SizedBox(
              width: 480,
              height: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Alege tipul corect din taxonomie',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: IncidentTaxonomy.all.length,
                      itemBuilder: (context, index) {
                        final type = IncidentTaxonomy.all[index];
                        final isSelected = type.code == selectedCode;
                        return ListTile(
                          selected: isSelected,
                          leading: Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                          ),
                          title: Text('${type.code} · ${type.labelRo}'),
                          subtitle: Text(
                            '${type.category.labelRo} · ${type.urgency.labelRo}',
                          ),
                          onTap: () => setLocal(() {
                            selectedCode = type.code;
                            selectedUrgency ??= type.urgency;
                          }),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Urgență (opțional, peste default)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Urgency?>(
                        isExpanded: true,
                        value: selectedUrgency ?? selected.urgency,
                        items: <DropdownMenuItem<Urgency?>>[
                          for (final u in Urgency.values)
                            DropdownMenuItem<Urgency?>(
                              value: u,
                              child: Text(u.labelRo),
                            ),
                        ],
                        onChanged: (value) =>
                            setLocal(() => selectedUrgency = value),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Anulează'),
              ),
              FilledButton(
                onPressed: () {
                  final code = selectedCode;
                  if (code == null) return;
                  Navigator.of(context).pop(
                    ReclassifyChoice(
                      incidentCode: code,
                      urgency: selectedUrgency ?? selected.urgency,
                    ),
                  );
                },
                child: const Text('Aplică'),
              ),
            ],
          );
        },
      );
    },
  );
}
