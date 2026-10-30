// =============================================================================
// lib/features/auth/login_screen.dart
//
// OWNER: Lead (auth surface). Hardcoded demo-account sign-in behind the
// aerospace backdrop. Passwords are validated against salted SHA-256 hashes
// (see lib/core/auth/demo_accounts.dart) — no clear-text password is stored.
//
// UX rules for the demo:
//   • every account is one tap away and shows its demo password;
//   • tapping an account opens a small sheet with the password pre-filled,
//     so a judge can sign in in ~3 seconds while the hash check still runs;
//   • a restored session offers "Continuă ca <name>" (persistence is real).
// =============================================================================

import 'package:flutter/material.dart';

import '../../core/auth/demo_accounts.dart';
import '../../core/core_scope.dart';
import '../../core/models/session.dart';
import '../../core/theme/wingman_theme.dart';
import '../../core/widgets/sky_background.dart';
import '../dev/dev_tools_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    required this.onSignedIn,
    this.initialSession,
  });

  final ValueChanged<Session> onSignedIn;
  final Session? initialSession;

  @override
  Widget build(BuildContext context) {
    final board = CoreScope.boardOf(context);
    final restored = initialSession;

    return Scaffold(
      backgroundColor: WingmanColors.navy,
      body: SkyBackground(
        showGround: true,
        child: SafeArea(
          child: ListenableBuilder(
            listenable: board,
            builder: (context, _) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  WingmanSpacing.page,
                  WingmanSpacing.md,
                  WingmanSpacing.page,
                  WingmanSpacing.lg,
                ),
                children: <Widget>[
                  _Header(connected: board.connected),
                  const SizedBox(height: WingmanSpacing.lg),
                  if (restored != null) ...<Widget>[
                    _ResumeCard(
                      session: restored,
                      onContinue: () => onSignedIn(restored),
                    ),
                    const SizedBox(height: WingmanSpacing.lg),
                  ],
                  const Text(
                    'Alege un cont demo',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                      shadows: <Shadow>[
                        Shadow(color: Colors.black38, blurRadius: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: WingmanSpacing.md),
                  for (final account in demoAccounts) ...<Widget>[
                    _AccountCard(
                      account: account,
                      onTap: () => _openLoginSheet(context, account),
                    ),
                    const SizedBox(height: WingmanSpacing.sm),
                  ],
                  const SizedBox(height: WingmanSpacing.md),
                  const _Footer(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openLoginSheet(BuildContext context, DemoAccount account) async {
    final session = await showModalBottomSheet<Session>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _LoginSheet(account: account),
    );
    if (session != null && context.mounted) {
      onSignedIn(session);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(WingmanRadius.lg),
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(
                Icons.flight_takeoff_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: WingmanSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Wingman',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      shadows: <Shadow>[
                        Shadow(color: Colors.black38, blurRadius: 12),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Airport incident response · demo · '
                    '${SkyPeriod.current().labelRo}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      shadows: <Shadow>[
                        Shadow(color: Colors.black38, blurRadius: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'DevTools · aspect, server, acțiuni demo',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DevToolsScreen(),
                ),
              ),
              icon: const Icon(
                Icons.developer_mode_rounded,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        const SizedBox(height: WingmanSpacing.lg),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: WingmanSpacing.md,
            vertical: WingmanSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                connected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                size: 16,
                color: connected ? const Color(0xFF7CE8B4) : const Color(0xFFFFB4AB),
              ),
              const SizedBox(width: WingmanSpacing.sm),
              Text(
                connected ? 'Server conectat · live' : 'Server offline',
                style: TextStyle(
                  color: connected
                      ? const Color(0xFFB7F3D2)
                      : const Color(0xFFFFDAD6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  shadows: const <Shadow>[
                    Shadow(color: Colors.black26, blurRadius: 6),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.session, required this.onContinue});

  final Session session;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(WingmanSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: WingmanRadius.card,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.verified_user_outlined, color: WingmanColors.seed),
          const SizedBox(width: WingmanSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Bine ai revenit, ${session.displayName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: WingmanColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${session.scopeLabel} · sesiune salvată',
                  style: const TextStyle(
                    color: WingmanColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: onContinue,
            child: const Text('Continuă'),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account, required this.onTap});

  final DemoAccount account;
  final VoidCallback onTap;

  static IconData _iconFor(DemoAccount account) {
    if (account.isAdmin) return Icons.shield_outlined;
    return switch (account.username) {
      'engineer' => Icons.engineering_outlined,
      'janitor' => Icons.cleaning_services_outlined,
      'firefighter' => Icons.local_fire_department_outlined,
      'guard' => Icons.security_outlined,
      _ => Icons.record_voice_over_outlined,
    };
  }

  static Color _tintFor(DemoAccount account) {
    if (account.isAdmin) return WingmanColors.navy;
    return switch (account.username) {
      'engineer' => const Color(0xFF00695C),
      'janitor' => const Color(0xFF9A6A00),
      'firefighter' => const Color(0xFFC62828),
      'guard' => const Color(0xFF1B4F9C),
      _ => WingmanColors.seed,
    };
  }

  String get _scopeLabel {
    if (account.isAdmin) return 'Vezi și decizi tot · dispecerat';
    if (account.departments.isEmpty) return 'Raportare incidente';
    return 'Alertat doar pentru: '
        '${account.departments.map((d) => d.labelRo).join(' · ')}';
  }

  @override
  Widget build(BuildContext context) {
    final tint = _tintFor(account);
    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: WingmanRadius.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: WingmanRadius.card,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(WingmanRadius.sm),
                ),
                child: Icon(_iconFor(account), color: tint, size: 22),
              ),
              const SizedBox(width: WingmanSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            account.displayName,
                            style: const TextStyle(
                              color: WingmanColors.ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: tint.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            account.tag,
                            style: TextStyle(
                              color: tint,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${account.username} · ${_scopeLabel}',
                      style: const TextStyle(
                        color: WingmanColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'parolă demo: ${account.passwordHint}',
                      style: const TextStyle(
                        color: WingmanColors.muted,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: WingmanSpacing.sm),
              Icon(
                Icons.login_rounded,
                color: tint.withValues(alpha: 0.7),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginSheet extends StatefulWidget {
  const _LoginSheet({required this.account});

  final DemoAccount account;

  @override
  State<_LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends State<_LoginSheet> {
  late final TextEditingController _password =
      TextEditingController(text: widget.account.passwordHint);
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.account.checkPassword(_password.text)) {
      Navigator.of(context).pop(widget.account.toSession());
      return;
    }
    setState(() => _error = 'Parolă greșită pentru @${widget.account.username}.');
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(WingmanRadius.xl),
          ),
        ),
        padding: const EdgeInsets.all(WingmanSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Autentificare · ${widget.account.displayName}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: WingmanColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Cont hardcodat pentru demo; parola e verificată prin hash SHA-256.',
              style: const TextStyle(fontSize: 12, color: WingmanColors.muted),
            ),
            const SizedBox(height: WingmanSpacing.lg),
            TextField(
              controller: _password,
              obscureText: true,
              autofocus: true,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Parolă',
                errorText: _error,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
              ),
            ),
            const SizedBox(height: WingmanSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Anulează'),
                  ),
                ),
                const SizedBox(width: WingmanSpacing.md),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Intră în cont'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(Icons.lock_outline_rounded, size: 14, color: Colors.white54),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            'Demo offline · TLS pinned · clasificare AI locală',
            style: TextStyle(color: Colors.white54, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
