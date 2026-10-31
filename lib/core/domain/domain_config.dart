// =============================================================================
// lib/core/domain/domain_config.dart
//
// The *application profile*. Everything that changes when Wingman is reused for
// another venue/vertical (hospital, stadium, campus) and should NOT require
// touching feature code lives here, behind one JSON file:
//
//   config/domains/airport.json
//
// Select another profile at build time:
//   flutter build apk --dart-define=DOMAIN_CONFIG=config/domains/events.json
//
// The backend reads the same file through DOMAIN_CONFIG (see backend/app/domain.py),
// so branding, feature switches, rewards and quorum never drift between phone
// and server.
// =============================================================================

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

class DomainConfig {
  const DomainConfig({
    required this.schemaVersion,
    required this.id,
    required this.branding,
    required this.map,
    required this.features,
    required this.quorum,
    required this.rewards,
    required this.notifications,
    required this.demo,
  });

  static const String defaultAssetPath = String.fromEnvironment(
    'DOMAIN_CONFIG',
    defaultValue: 'config/domains/airport.json',
  );

  final int schemaVersion;
  final String id;
  final DomainBranding branding;
  final MapConfig map;
  final DomainFeatures features;
  final QuorumConfig quorum;
  final RewardConfig rewards;
  final NotificationConfig notifications;
  final DemoConfig demo;

  /// Safe fallback when the asset is missing/corrupt. Keeps the demo booting.
  static const DomainConfig fallback = DomainConfig(
    schemaVersion: 1,
    id: 'airport',
    branding: DomainBranding(
      appName: 'Wingman',
      tagline: 'Airport incident response',
      seedColorValue: 0xFF1D4E89,
      icon: 'flight_takeoff',
    ),
    map: MapConfig(
      provider: 'openstreetmap',
      tileUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      attribution: '© OpenStreetMap contributors',
      initialLat: 44.3189,
      initialLng: 23.8864,
      initialZoom: 15.5,
      maxZoom: 19,
    ),
    features: DomainFeatures(),
    quorum: QuorumConfig(
      strategy: 'one_per_primary_department',
      minimum: 1,
      fixed: 2,
    ),
    rewards: RewardConfig(
      strategy: 'rule_based',
      reportPoints: 2,
      attendedPoints: 0,
      resolvedBonus: 5,
      deniedPoints: 0,
      pointsLabel: 'PUNCTE',
    ),
    notifications: NotificationConfig(
      roles: <String>{'crew', 'dispatcher'},
      scope: 'primary_departments',
    ),
    demo: DemoConfig(seedTickets: 5, resetEnabled: true),
  );

  factory DomainConfig.fromJson(Map<String, dynamic> json) {
    final branding = _map(json['branding']);
    final map = _map(json['map']);
    final features = _map(json['features']);
    final quorum = _map(json['quorum']);
    final rewards = _map(json['rewards']);
    final notifications = _map(json['notifications']);
    final demo = _map(json['demo']);

    return DomainConfig(
      schemaVersion: _int(json['schemaVersion'], 1),
      id: _string(json['id'], 'airport'),
      branding: DomainBranding(
        appName: _string(branding['appName'], 'Wingman'),
        tagline: _string(
          branding['tagline'],
          'Airport incident response',
        ),
        seedColorValue: _hexColor(branding['seedColor']),
        icon: _string(branding['icon'], 'flight_takeoff'),
      ),
      map: MapConfig(
        provider: _string(map['provider'], 'openstreetmap'),
        tileUrl: _string(
          map['tileUrl'],
          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        ),
        attribution:
            _string(map['attribution'], '© OpenStreetMap contributors'),
        initialLat: _double(map['initialLat'], 44.3189),
        initialLng: _double(map['initialLng'], 23.8864),
        initialZoom: _double(map['initialZoom'], 15.5),
        maxZoom: _double(map['maxZoom'], 19),
      ),
      features: DomainFeatures(
        rewards: _bool(features['rewards'], true),
        gpsMap: _bool(features['gpsMap'], true),
        photo: _bool(features['photo'], true),
        accessibility: _bool(features['accessibility'], true),
        history: _bool(features['history'], true),
        demoReset: _bool(features['demoReset'], true),
      ),
      quorum: QuorumConfig(
        strategy: _string(
          quorum['strategy'],
          'one_per_primary_department',
        ),
        minimum: _int(quorum['minimum'], 1),
        fixed: _int(quorum['fixed'], 2),
      ),
      rewards: RewardConfig(
        strategy: _string(rewards['strategy'], 'rule_based'),
        reportPoints: _int(rewards['reportPoints'], 2),
        attendedPoints: _int(rewards['attendedPoints'], 0),
        resolvedBonus: _int(rewards['resolvedBonus'], 5),
        deniedPoints: _int(rewards['deniedPoints'], 0),
        pointsLabel: _string(rewards['pointsLabel'], 'PUNCTE'),
      ),
      notifications: NotificationConfig(
        roles: _stringSet(
          notifications['roles'],
          const <String>{'crew', 'dispatcher'},
        ),
        scope: _string(
          notifications['scope'],
          'primary_departments',
        ),
      ),
      demo: DemoConfig(
        seedTickets: _int(demo['seedTickets'], 5),
        resetEnabled: _bool(demo['resetEnabled'], true),
      ),
    );
  }

  static Future<DomainConfig> load({String? assetPath}) async {
    final path = assetPath ?? defaultAssetPath;
    try {
      final raw = await rootBundle.loadString(path);
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Domain config root must be an object');
      }
      final config = DomainConfig.fromJson(decoded);
      debugPrint(
        '[domain] loaded ${config.id} from $path · '
        'rewards=${config.rewards.strategy} · '
        'quorum=${config.quorum.strategy}',
      );
      return config;
    } on Object catch (error) {
      debugPrint('[domain] could not load $path ($error); using fallback');
      return fallback;
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': schemaVersion,
        'id': id,
        'branding': <String, dynamic>{
          'appName': branding.appName,
          'tagline': branding.tagline,
          'seedColor':
              '#${branding.seedColorValue.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
          'icon': branding.icon,
        },
        'map': map.toJson(),
        'features': <String, dynamic>{
          'rewards': features.rewards,
          'gpsMap': features.gpsMap,
          'photo': features.photo,
          'accessibility': features.accessibility,
          'history': features.history,
          'demoReset': features.demoReset,
        },
        'quorum': quorum.toJson(),
        'rewards': rewards.toJson(),
        'notifications': notifications.toJson(),
        'demo': demo.toJson(),
      };
}

class DomainBranding {
  const DomainBranding({
    required this.appName,
    required this.tagline,
    required this.seedColorValue,
    required this.icon,
  });

  final String appName;
  final String tagline;
  final int seedColorValue;
  final String icon;
}

class MapConfig {
  const MapConfig({
    required this.provider,
    required this.tileUrl,
    required this.attribution,
    required this.initialLat,
    required this.initialLng,
    required this.initialZoom,
    required this.maxZoom,
  });

  final String provider;
  final String tileUrl;
  final String attribution;
  final double initialLat;
  final double initialLng;
  final double initialZoom;
  final double maxZoom;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'provider': provider,
        'tileUrl': tileUrl,
        'attribution': attribution,
        'initialLat': initialLat,
        'initialLng': initialLng,
        'initialZoom': initialZoom,
        'maxZoom': maxZoom,
      };
}

class DomainFeatures {
  const DomainFeatures({
    this.rewards = true,
    this.gpsMap = true,
    this.photo = true,
    this.accessibility = true,
    this.history = true,
    this.demoReset = true,
  });

  final bool rewards;
  final bool gpsMap;
  final bool photo;
  final bool accessibility;
  final bool history;
  final bool demoReset;
}

class QuorumConfig {
  const QuorumConfig({
    required this.strategy,
    required this.minimum,
    required this.fixed,
  });

  final String strategy;
  final int minimum;
  final int fixed;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'strategy': strategy,
        'minimum': minimum,
        'fixed': fixed,
      };
}

class RewardConfig {
  const RewardConfig({
    required this.strategy,
    required this.reportPoints,
    required this.attendedPoints,
    required this.resolvedBonus,
    required this.deniedPoints,
    required this.pointsLabel,
  });

  final String strategy;
  final int reportPoints;
  final int attendedPoints;
  final int resolvedBonus;
  final int deniedPoints;
  final String pointsLabel;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'strategy': strategy,
        'reportPoints': reportPoints,
        'attendedPoints': attendedPoints,
        'resolvedBonus': resolvedBonus,
        'deniedPoints': deniedPoints,
        'pointsLabel': pointsLabel,
      };
}

class NotificationConfig {
  const NotificationConfig({
    required this.roles,
    required this.scope,
  });

  final Set<String> roles;
  final String scope;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'roles': roles.toList()..sort(),
        'scope': scope,
      };
}

class DemoConfig {
  const DemoConfig({required this.seedTickets, required this.resetEnabled});

  final int seedTickets;
  final bool resetEnabled;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'seedTickets': seedTickets,
        'resetEnabled': resetEnabled,
      };
}

// ── parsing helpers ─────────────────────────────────────────────────────────

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : <String, dynamic>{};

String _string(Object? value, String fallback) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return fallback;
}

int _int(Object? value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

bool _bool(Object? value, bool fallback) {
  if (value is bool) return value;
  if (value is String) {
    return <String>{'1', 'true', 'yes', 'on'}.contains(value.toLowerCase());
  }
  return fallback;
}

double _double(Object? value, double fallback) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int _hexColor(Object? value) {
  if (value is! String) return 0xFF1D4E89;
  final clean = value.replaceFirst('#', '').trim();
  final parsed = int.tryParse(clean, radix: 16);
  if (parsed == null) return 0xFF1D4E89;
  return clean.length <= 6 ? 0xFF000000 | parsed : parsed;
}

Set<String> _stringSet(Object? value, Set<String> fallback) {
  if (value is! List) return fallback;
  final items = value.whereType<String>().map((e) => e.trim().toLowerCase());
  return items.isEmpty ? fallback : items.toSet();
}
