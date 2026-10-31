import 'package:flutter/material.dart';

import 'accessibility_settings.dart';

class AccessibilityScreen extends StatelessWidget {
  const AccessibilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AccessibilitySettings.instance;
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final theme = Theme.of(context);
        return Scaffold(
          appBar: AppBar(title: const Text('Accesibilitate')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Text(
                'Profil rapid',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Alege un profil — setările de mai jos se aplică imediat '
                'în toată aplicația.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final profile in AccessibilityProfile.values)
                    ChoiceChip(
                      label: Text(profile.labelRo),
                      selected: settings.profile == profile,
                      onSelected: (_) => settings.applyProfile(profile),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'Text și contrast',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<double>(
                segments: const <ButtonSegment<double>>[
                  ButtonSegment<double>(value: 1.0, label: Text('Normal')),
                  ButtonSegment<double>(value: 1.25, label: Text('Mare')),
                  ButtonSegment<double>(value: 1.5, label: Text('Foarte mare')),
                ],
                selected: <double>{settings.textScale},
                onSelectionChanged: (value) =>
                    settings.setTextScale(value.first),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Contrast ridicat'),
                subtitle: const Text('Contururi și culori mai puternice'),
                value: settings.highContrast,
                onChanged: (value) => settings.setFlag('highContrast', value),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Paletă sigură pentru daltonism'),
                subtitle: const Text(
                  'Nu se bazează doar pe roșu/verde; etichetele rămân vizibile',
                ),
                value: settings.colorBlindSafe,
                onChanged: (value) => settings.setFlag('colorBlindSafe', value),
              ),
              const SizedBox(height: 12),
              Text(
                'Comunicare și alertare',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Alerte vizuale + vibrație'),
                subtitle: const Text(
                  'Pentru persoane surde / hipoacuzice: notificarea nu depinde '
                  'doar de sunet',
                ),
                value: settings.visualAlerts,
                onChanged: (value) => settings.setFlag('visualAlerts', value),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ghidaj vocal'),
                subtitle: const Text(
                  'Pentru persoane cu vedere redusă: confirmări și pași citiți',
                ),
                value: settings.spokenGuidance,
                onChanged: (value) => settings.setFlag('spokenGuidance', value),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mod tastare prioritar'),
                subtitle: const Text(
                  'Pentru persoane mute: meniul și tastatura sunt primele opțiuni',
                ),
                value: settings.typedFirst,
                onChanged: (value) => settings.setFlag('typedFirst', value),
              ),
              const SizedBox(height: 12),
              Text(
                'Interacțiune',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ținte de atingere mari'),
                subtitle: const Text(
                  'Butoane mai înalte, potrivite pentru mobilitate redusă',
                ),
                value: settings.largeTargets,
                onChanged: (value) => settings.setFlag('largeTargets', value),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Limbaj simplificat'),
                subtitle: const Text(
                  'Propoziții scurte și etichete clare pentru profil cognitiv',
                ),
                value: settings.simplifiedLanguage,
                onChanged: (value) =>
                    settings.setFlag('simplifiedLanguage', value),
              ),
              const SizedBox(height: 16),
              Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Cum se aplică',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Textul și contrastul se aplică global. Profilul mut '
                        'pune meniul/tastarea în prim-plan; profilul surd '
                        'pornește alertele vizuale; profilul orb pornește '
                        'ghidajul vocal și țintele mari.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: settings.reset,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Resetează accesibilitatea'),
              ),
            ],
          ),
        );
      },
    );
  }
}
