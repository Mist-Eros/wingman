// =============================================================================
// lib/core/core_scope.dart
//
// OWNER: Lead (lib/core/). The ONLY dependency-injection mechanism in the app:
// an InheritedWidget carrying the ApiClient, TicketBoard and Session.
//
// Feature screens (reporter / dispatcher / crew) must never receive these via
// constructor parameters from `main.dart`. They read:
//
//   final session = CoreScope.sessionOf(context);   // who am I
//   final board   = CoreScope.boardOf(context);     // live tickets
//   final api     = CoreScope.apiOf(context);       // REST + WSS
//   CoreScope.of(context).onSignOut();              // back to role screen
//
// That keeps `main.dart` (Lead-owned) free to change and keeps the three
// feature folders independently mergeable.
// =============================================================================

import 'package:flutter/widgets.dart';

import 'api/api_client.dart';
import 'auth/token_store.dart';
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
    required super.child,
  });

  final ApiClient api;
  final TicketBoard board;
  final TokenStore tokenStore;

  /// null only on the role-picker screen (before a role is chosen).
  final Session? session;

  final VoidCallback onSignOut;

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
      onSignOut != oldWidget.onSignOut;
}
