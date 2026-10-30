# Design tokens — Wingman

Single source of truth: `lib/core/theme/wingman_theme.dart` (Lead-owned).
**Never hardcode a hex in a feature screen** — pull from `Theme.of(context)` or the
`WingmanColors` / `WingmanTheme` helpers. This is what keeps reporter/dispatcher/crew
looking like one product instead of three.

## Brand

| Token | Value | Use |
|---|---|---|
| `WingmanColors.seed` | `#1D4E89` | Material 3 seed (primary buttons, focus) |
| `WingmanColors.navy` | `#123A63` | Headlines, brand mark, app bar accents |
| `WingmanColors.ink` | `#102038` | Body text |
| `WingmanColors.muted` | `#5A6B84` | Secondary text, icons |
| `WingmanColors.background` | `#F5F7FB` | Scaffold (cool paper) |
| `WingmanColors.surface` | `#FFFFFF` | Cards, inputs |
| `WingmanColors.surfaceMuted` | `#EEF2F8` | Chips, icon wells |
| `WingmanColors.line` | `#E1E7F1` | 1 px borders / dividers |

## Semantic colors (the only way to show urgency/status)

| Meaning | Text/border | Fill |
|---|---|---|
| `Urgency.critical` | `#C62828` | `#FDECEC` |
| `Urgency.high` | `#D84315` | `#FDEFE7` |
| `Urgency.medium` | `#9A6A00` | `#FFF5D6` |
| `Urgency.low` | `#2E7D32` | `#EAF6EB` |
| `pending_override` | `#9A5B00` | `#FFF1DC` |
| `dispatched` | `#1565C0` | `#E8F1FD` |
| `in_progress` | `#B45309` | `#FDECD8` |
| `resolved` | `#2E7D32` | `#EAF6EB` |
| `denied` | `#5B6B82` | `#EEF1F5` |
| live / WSS ok | `#1B7F5A` | `#E6F4EE` |

Helpers:

```dart
WingmanTheme.urgencyColor(ticket.urgency);   // text/border
WingmanTheme.urgencyFill(ticket.urgency);    // chip background
WingmanTheme.statusColor(ticket.status);     // text/border
WingmanTheme.statusFill(ticket.status);      // chip background
```

Rule: **color never carries meaning alone** — pair it with an icon or the Romanian
label (accessibility + projector contrast).

## Scale

`WingmanSpacing`: `xs 4 · sm 8 · md 12 · lg 16 · xl 24 · xxl 32 · page 20`
`WingmanRadius`: `sm 10 · md 14 · lg 18 (cards) · xl 24 (dialogs/sheets)`

## Components (already themed globally)

- **AppBar** — transparent over the page background, `headlineSmall`, no elevation.
- **Card** — white, 1 px `line` border, radius 18, **no shadow**; shadow only on the
  active override card (`WingmanTheme.softShadow`).
- **FilledButton** — 50 px min height, radius 14, `labelLarge` w600.
- **Inputs** — filled white, radius 14, 1.6 px primary focus border.
- **Chips** — outlined pill (`surfaceMuted` fill), w600 labels.
- **SnackBar** — floating, radius 14, ink background.
- **Dialogs/sheets** — radius 24, no surface tint.

## Component patterns to use in new screens

1. Page title = `headlineSmall` navy; helper line = `bodySmall` muted.
2. Ticket card: urgency chip + status chip on top, title in `titleMedium`, meta rows
   with 16 px muted icons, actions at the bottom in a `Row` with `Expanded` buttons.
3. Empty state: 48 px muted icon in a `surfaceMuted` circle, `titleMedium` text,
   one sentence in `bodySmall` muted.
4. Live/WSS badge: `liveFill` pill + `wifi_rounded` icon + „WSS conectat".
5. Never show a raw exception string: map errors to one action sentence
   (see `ApiException.message`).

## Typography

Default Roboto; weights tighten the hierarchy: display/headline w700, titles w600-700,
labels w600, body regular. Romanian diacritics (ă â î ș ț) are fully supported.
