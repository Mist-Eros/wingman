// =============================================================================
// lib/core/core_scope.dart
//
// OWNER: Lead (lib/core/). The ONLY dependency-injection mechanism in the app:
// an InheritedWidget carrying the ApiClient, TicketBoard, Session, active
// DomainConfig and pluggable services (rewards, demo reset).
//
// Feature screens must never receive these via constructor parameters from
// `main.dart`. They read:
//
//   final session = CoreScope.sessionOf(context);   // who am I
//   final board   = CoreScope.boardOf(context);     // live tickets
//   final api     = CoreScope.apiOf(context);       // REST + WSS
//   final domain  = CoreScope.domainOf(context);    // app profile/features
//   final rewards = CoreScope.rewardsOf(context);   // pluggable ledger
//   CoreScope.of(context).onSignOut();              // back to role screen
// =============================================================================

import 'package:flutter/widgets.dart';

import 'rewards/reward_service.dart';
import 'api/api_client.dart';
import 'auth/token_store.dart';
import 'demo/demo_reset_service.dart';
import 'domain/domain_config.dart';
import 'models/session.dart';
import 'state/ticket_board.dart';

class CoreScope extends InheritedWidget {
  const CoreScope({
    super.key,
    required this.api,
    required this.board,
    required this.tokenStore,
    required this.session,
    required this.onSignOut,
    this.domainConfig,
    this.rewardService,
    this.demoResetService,
    this.onLocalModeChanged,
    required super.child,
  });

  final ApiClient api;
  final TicketBoard board;
  final TokenStore tokenStore;

  /// null only on the role-picker screen (before a role is chosen).
  final Session? session;

  /// Optional injections keep widget tests and alternate verticals simple.
  final DomainConfig? domainConfig;
  final RewardService? rewardService;
  final DemoResetService? demoResetService;

  /// Swaps between the live REST/WSS board and the in-memory demo board.
  final ValueChanged<bool>? onLocalModeChanged;

  final VoidCallback onSignOut;

  DomainConfig get domain => domainConfig ?? DomainConfig.fallback;

  RewardService get rewards =>
      rewardService ?? RewardService.fromDomain(domain);

  DemoResetService get demoReset =>
      demoResetService ?? DemoResetService(api: api, board: board);

  static CoreScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CoreScope>();
    if (scope == null) {
      throw FlutterError(
        'CoreScope not found above this context. Screens must be mounted by '
        'main.dart (or a widget test must wrap them in CoreScope).',
      );
    }
    return scope;
  }

  static CoreScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CoreScope>();

  static ApiClient apiOf(BuildContext context) => of(context).api;

  static TicketBoard boardOf(BuildContext context) => of(context).board;

  static DomainConfig domainOf(BuildContext context) => of(context).domain;

  /// Safe variant for reusable widgets/test harnesses that may not mount the
  /// full CoreScope (e.g. a focused reporter widget test).
  static DomainConfig domainOrFallbackOf(BuildContext context) =>
      maybeOf(context)?.domain ?? DomainConfig.fallback;

  static RewardService rewardsOf(BuildContext context) => of(context).rewards;

  static Session sessionOf(BuildContext context) {
    final session = of(context).session;
    if (session == null) {
      throw FlutterError(
        'No session selected. Only the role-picker screen may render before a '
        'role is chosen.',
      );
    }
    return session;
  }

  static Session? maybeSessionOf(BuildContext context) =>
      maybeOf(context)?.session;

  @override
  bool updateShouldNotify(CoreScope oldWidget) =>
      api != oldWidget.api ||
      board != oldWidget.board ||
      tokenStore != oldWidget.tokenStore ||
      session != oldWidget.session ||
      domainConfig != oldWidget.domainConfig ||
      rewardService != oldWidget.rewardService ||
      demoResetService != oldWidget.demoResetService ||
      onLocalModeChanged != oldWidget.onLocalModeChanged ||
      onSignOut != oldWidget.onSignOut;
}
