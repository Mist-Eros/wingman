import 'package:flutter/material.dart';

/// Visual density for projector vs laptop.
enum DispatcherDensity {
  comfortable,
  compact,
}

extension DispatcherDensityX on DispatcherDensity {
  String get labelRo => switch (this) {
        DispatcherDensity.comfortable => 'Confortabil',
        DispatcherDensity.compact => 'Compact',
      };

  double get cardGap => switch (this) {
        DispatcherDensity.comfortable => 12,
        DispatcherDensity.compact => 8,
      };

  EdgeInsets get cardPadding => switch (this) {
        DispatcherDensity.comfortable => const EdgeInsets.fromLTRB(14, 14, 14, 12),
        DispatcherDensity.compact => const EdgeInsets.fromLTRB(10, 10, 10, 8),
      };

  double get titleSize => switch (this) {
        DispatcherDensity.comfortable => 16,
        DispatcherDensity.compact => 14,
      };
}
