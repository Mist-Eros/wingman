// 8×8×8 incident menu: 8 categories → 8 subcategories → 8 problems.
//
// The grid is always 2 rows × 4 buttons and fills the whole screen. Selecting
// a problem is the third tap; the caller can then submit the report with the
// problem's operational code and its exact label/location.

import 'package:flutter/material.dart';

import 'menu/incident_menu_data.dart';
import 'menu/menu_language.dart';
import 'reporter_language.dart';

class IncidentMenuPage extends StatefulWidget {
  const IncidentMenuPage({super.key, required this.language});

  final ReporterLanguage language;

  @override
  State<IncidentMenuPage> createState() => _IncidentMenuPageState();
}

class _IncidentMenuPageState extends State<IncidentMenuPage> {
  MenuCategory? _category;
  MenuSubcategory? _subcategory;

  Tr get _tr => Tr(widget.language);

  int get _level => _subcategory != null ? 2 : (_category != null ? 1 : 0);

  String get _title {
    if (_subcategory != null) {
      return localizedMenuSubcategory(_subcategory!.label, widget.language);
    }
    if (_category != null) {
      return localizedMenuCategory(_category!.label, widget.language);
    }
    return _tr('Ce s-a întâmplat?', 'What happened?');
  }

  String? get _path {
    if (_subcategory != null) {
      return localizedMenuPath(_category!, _subcategory!, widget.language);
    }
    return null;
  }

  void _back() {
    setState(() {
      if (_subcategory != null) {
        _subcategory = null;
      } else if (_category != null) {
        _category = null;
      }
    });
  }

  void _selectProblem(MenuProblem problem) {
    Navigator.of(context).pop(
      MenuSelection(_category!, _subcategory!, problem),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onLevelZero = _level == 0;

    return PopScope(
      canPop: onLevelZero,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: onLevelZero
              ? null
              : IconButton(
                  tooltip: _tr('Înapoi', 'Back'),
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: _back,
                ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (_path != null)
                Text(
                  _path!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tiles = _level == 0
                  ? <Widget>[
                      for (final category in menuCategories)
                        _MenuTile(
                          icon: category.icon,
                          label: localizedMenuCategory(
                            category.label,
                            widget.language,
                          ),
                          onTap: () => setState(() => _category = category),
                        ),
                    ]
                  : _level == 1
                      ? <Widget>[
                          for (final subcategory in _category!.subcategories)
                            _MenuTile(
                              icon: _category!.icon,
                              label: localizedMenuSubcategory(
                                subcategory.label,
                                widget.language,
                              ),
                              onTap: () => setState(
                                () => _subcategory = subcategory,
                              ),
                            ),
                        ]
                      : <Widget>[
                          for (final problem in _subcategory!.problems)
                            _MenuTile(
                              icon: _category!.icon,
                              label: localizedMenuProblem(
                                _subcategory!,
                                problem,
                                widget.language,
                              ),
                              footer: problem.typeCode,
                              dense: true,
                              onTap: () => _selectProblem(problem),
                            ),
                        ];

              // Four rows of two fill the available height exactly.
              final height =
                  ((constraints.maxHeight - 44) / 4).clamp(72.0, 260.0);

              return GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                itemCount: 8,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: height,
                ),
                itemBuilder: (context, index) => tiles[index],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.footer,
    this.dense = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? footer;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: dense ? 28 : 36, color: scheme.primary),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: dense ? 14 : 16,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              if (footer != null) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  footer!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
