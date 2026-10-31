// =============================================================================
// lib/main.dart
//
// OWNER: Lead. Single app, role-based routing (per the locked product split):
//
//   /            â†’ LoginScreen (hardcoded demo accounts, hashed passwords)
//   /reporter    â†’ lib/features/reporter/     (Cutulescu Andrei-Rares)
//   /dispatcher  â†’ lib/features/dispatcher/  (Fita Redu Mihai / admin)
//   /crew        â†’ lib/features/crew/        (Lica Rares Adelin / scoped crews)
//
// Back behaviour: role screens are PUSHED over the login screen, so Android's
// back button returns to the account chooser instead of killing the app.
//
// Run against your laptop (compiled-in, no runtime config):
//   flutter run \
//     --dart-define=API_BASE=https://192.168.1.50:8443 \
//     --dart-define=API_TOKEN=demo-token
// Emergency dev-only fallback (plain HTTP, accepts any cert):
//   flutter run --dart-define=API_BASE=http://192.168.1.50:8080 \
//               --dart-define=DEV_INSECURE=true
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'core/accessibility/accessibility_settings.dart';
import 'core/api/api_client.dart';
import 'core/auth/demo_accounts.dart';
import 'core/auth/secure_token_store.dart';
import 'core/auth/session_store.dart';
import 'core/auth/token_store.dart';
import 'core/core_scope.dart';
import 'core/domain/domain_config.dart';
import 'core/incidents/taxonomy.dart';
import 'core/models/session.dart';
import 'core/notifications/ticket_notifier.dart';
import 'core/state/ticket_board.dart';
import 'core/theme/wingman_theme.dart';
import 'features/auth/login_screen.dart';
import 'core/rewards/reward_service.dart';
import 'features/crew/crew_screen.dart';
import 'features/dispatcher/dispatcher_screen.dart';
import 'features/reporter/reporter_screen.dart';

/// Raw values straight from `--dart-define`. A broken build can merge several
/// define flags into one value, so these are sanitized before use.
const String _kApiBaseRaw = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://wingman.local:8443',
);

const String _kApiTokenRaw = String.fromEnvironment(
  'API_TOKEN',
  defaultValue: 'demo-token',
);

String _firstToken(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.split(RegExp(r'\s+')).first;
}

/// Validated base URL, or the documented default when the define is unusable.
/// Never let a bad `--dart-define` crash the demo with a FormatException.
String _sanitizeApiBase(String raw) {
  final candidate = _firstToken(raw);
  final uri = Uri.tryParse(candidate);
  final valid = uri != null &&
      (uri.isScheme('http') || uri.isScheme('https')) &&
      uri.host.isNotEmpty;
  return valid ? candidate : 'https://wingman.local:8443';
}

/// Laptop LAN address + port serving HTTPS/WSS. Overridden per build:
///   --dart-define=API_BASE=https://192.168.1.50:8443
final String kApiBase = _sanitizeApiBase(_kApiBaseRaw);

/// Demo bearer token; must match `API_TOKEN` on the backend.
final String kApiToken = _firstToken(_kApiTokenRaw).isEmpty
    ? 'demo-token'
    : _firstToken(_kApiTokenRaw);

/// DEV ONLY. Accepts any TLS certificate. Keep false for the judged demo.
const bool kDevInsecure = bool.fromEnvironment(
  'DEV_INSECURE',
  defaultValue: false,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fail fast during development if someone edits the taxonomy into an
  // invalid state (wrong count, duplicate code, empty department list).
  assert(() {
    IncidentTaxonomy.validate();
    return true;
  }());
  debugPrint(
    '[boot] taxonomy v${IncidentTaxonomy.schemaVersion}: '
    '${IncidentTaxonomy.all.length} types, API=$kApiBase, insecure=$kDevInsecure',
  );

  final domain = await DomainConfig.load();

  final caPem = await _loadCaPem();
  final api = ApiClient(
    baseUrl: kApiBase,
    token: kApiToken,
    caPem: caPem,
    allowInsecure: kDevInsecure,
  );

  // Secure token storage + persisted session, so the account identity (crew id,
  // department scope) survives an app restart. Both fall back gracefully.
  final tokenStore = SecureTokenStore(fallback: kApiToken);
  final sessionStore = SecureSessionStore();
  final savedSession = await sessionStore.read();
  // Upgrade old saved sessions with the current account scope/admin flags.
  final initialSession =
      savedSession == null ? null : restoreSession(savedSession);
  final board = TicketBoard(api: api);

  runApp(
    AirportApp(
      api: api,
      board: board,
      tokenStore: tokenStore,
      sessionStore: sessionStore,
      initialSession: initialSession,
      domain: domain,
    ),
  );
}

/// Loads the self-signed CA bundled as a Flutter asset. Missing asset is a
/// warning, not a crash: the app still boots and shows an actionable error.
Future<String?> _loadCaPem() async {
  try {
    final pem = await rootBundle.loadString('assets/certs/ca.crt');
    if (pem.trim().isEmpty) {
      debugPrint('[cert] assets/certs/ca.crt is empty.');
      return null;
    }
    return pem;
  } on Object catch (error) {
    debugPrint(
      '[cert] assets/certs/ca.crt missing ($error). Run '
      'scripts/gen_certs.ps1, then `flutter pub get`. Until then only '
      '--dart-define=DEV_INSECURE=true will work.',
    );
    return null;
  }
}

class AirportApp extends StatefulWidget {
  const AirportApp({
    super.key,
    required this.api,
    required this.board,
    required this.tokenStore,
    required this.sessionStore,
    this.initialSession,
    required this.domain,
  });

  final ApiClient api;
  final TicketBoard board;
  final TokenStore tokenStore;
  final SessionStore sessionStore;

  /// Restored on launch so the account identity survives an app restart.
  final Session? initialSession;

  /// Active application profile (branding, features, rewards, quorum).
  final DomainConfig domain;

  @override
  State<AirportApp> createState() => _AirportAppState();
}

class _AirportAppState extends State<AirportApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final TicketNotifier _notifier = TicketNotifier();
  late final TicketAlertPolicy _alertPolicy;
  Session? _session;
  bool _notifierReady = false;
  bool _initialSnapshotHandled = false;

  @override
  void initState() {
    super.initState();
    _session = widget.initialSession;
    _alertPolicy = TicketAlertPolicy(
      rules: TicketAlertRules(
        roles: widget.domain.notifications.roles,
      ),
    );
    // One WSS connection for the whole app lifetime; the board fans events out
    // to every screen through ListenableBuilder.
    unawaited(widget.board.start());
    widget.board.addListener(_onBoardChanged);
    unawaited(_initNotifications());
  }

  Future<void> _initNotifications() async {
    try {
      await _notifier.init();
      if (!mounted) return;
      setState(() => _notifierReady = true);
    } on Object catch (error) {
      debugPrint('[notify] init failed: $error');
    }
  }

  /// Fires a local notification for every NEW active ticket that matches the
  /// signed-in account's departments. Reporters get none; crew get exactly the
  /// departments they are responsible for.
  void _onBoardChanged() {
    final session = _session;
    if (session == null) return;
    if (!_initialSnapshotHandled) {
      // Don't buzz the phone for history that already existed on launch.
      _alertPolicy.seed(widget.board.tickets);
      _initialSnapshotHandled = true;
      return;
    }
    if (!_notifierReady) return;
    final alerts =
        _alertPolicy.alertsFor(tickets: widget.board.tickets, session: session);
    for (final ticket in alerts) {
      unawaited(_notifier.showTicket(ticket));
    }
  }

  @override
  void dispose() {
    widget.board.removeListener(_onBoardChanged);
    widget.board.dispose();
    unawaited(widget.api.close());
    super.dispose();
  }

  void _signIn(Session session) {
    setState(() => _session = session);
    _alertPolicy.clear();
    _alertPolicy.seed(widget.board.tickets);
    _initialSnapshotHandled = true;
    unawaited(widget.sessionStore.write(session));
    if (_alertPolicy.rules.wants(session)) {
      unawaited(_notifier.requestPermissions());
    }
    // PUSH over the login screen (not replace): Android back returns to the
    // account chooser instead of closing the app.
    _navigatorKey.currentState?.pushNamed(session.role.route);
  }

  void _signOut() {
    setState(() => _session = null);
    _alertPolicy.clear();
    _initialSnapshotHandled = false;
    unawaited(widget.sessionStore.clear());
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return CoreScope(
      api: widget.api,
      board: widget.board,
      tokenStore: widget.tokenStore,
      session: _session,
      onSignOut: _signOut,
      domainConfig: widget.domain,
      rewardService: RewardService.fromDomain(widget.domain),
      child: MaterialApp(
        title: widget.domain.branding.appName,
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        theme: WingmanTheme.light(),
        darkTheme: WingmanTheme.dark(),
        themeMode: ThemeMode.light,
        builder: (context, child) {
          final access = AccessibilitySettings.instance;
          return AnimatedBuilder(
            animation: access,
            builder: (context, _) {
              final base = WingmanTheme.light();
              final scheme = ColorScheme.fromSeed(
                seedColor: access.colorBlindSafe
                    ? const Color(0xFF005F73)
                    : Color(widget.domain.branding.seedColorValue),
                brightness: Brightness.light,
                contrastLevel: access.highContrast ? 1.0 : 0.0,
              );
              final theme = base.copyWith(
                colorScheme: scheme,
                visualDensity: access.largeTargets
                    ? VisualDensity.comfortable
                    : VisualDensity.standard,
                materialTapTargetSize: access.largeTargets
                    ? MaterialTapTargetSize.padded
                    : MaterialTapTargetSize.shrinkWrap,
              );
              final media = MediaQuery.of(context);
              return MediaQuery(
                data: media.copyWith(
                  textScaler: TextScaler.linear(access.textScale),
                ),
                child: Theme(data: theme, child: child ?? const SizedBox()),
              );
            },
          );
        },
        initialRoute: '/',
        routes: <String, WidgetBuilder>{
          '/': (context) => _login(),
          UserRole.reporter.route: (context) => _guard(const ReporterScreen()),
          UserRole.dispatcher.route: (context) =>
              _guard(const DispatcherScreen()),
          UserRole.crew.route: (context) => _guard(const CrewScreen()),
        },
      ),
    );
  }

  /// Prevents a cold deep-link into a feature screen before an account is
  /// chosen (which would throw in `CoreScope.sessionOf`).
  Widget _guard(Widget screen) => _session == null ? _login() : screen;

  Widget _login() => LoginScreen(
        onSignedIn: _signIn,
        initialSession: _session,
      );
}
