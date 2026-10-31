// Reusable incident media panel: Foto / Hartă toggle for a ticket.
//
// The ticket keeps both the photo and the GPS location. This panel makes them
// visible everywhere (dispatcher detail, crew card, sent confirmation) instead
// of hiding the photo in one corner of one screen.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core_scope.dart';
import '../domain/domain_config.dart';
import '../models/ticket.dart';
import '../theme/wingman_theme.dart';

enum TicketMediaView { photo, map }

class TicketMediaPanel extends StatefulWidget {
  const TicketMediaPanel({
    super.key,
    required this.ticket,
    this.height = 190,
    this.compact = false,
  });

  final Ticket ticket;
  final double height;

  /// Compact mode for crew cards: smaller chrome, same toggle.
  final bool compact;

  @override
  State<TicketMediaPanel> createState() => _TicketMediaPanelState();
}

class _TicketMediaPanelState extends State<TicketMediaPanel> {
  TicketMediaView? _view;

  bool get _hasPhoto =>
      widget.ticket.photoBase64 != null &&
      widget.ticket.photoBase64!.trim().isNotEmpty;

  TicketMediaView get _activeView {
    if (_view != null) return _view!;
    return _hasPhoto ? TicketMediaView.photo : TicketMediaView.map;
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    final domain = CoreScope.domainOrFallbackOf(context);
    final config = domain.map;
    final hasCoords =
        ticket.location.lat != null && ticket.location.lng != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(widget.compact ? 14 : 16),
        border: Border.all(color: WingmanColors.line),
      ),
      padding: EdgeInsets.all(widget.compact ? 10 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    if (_hasPhoto)
                      _MediaChip(
                        icon: Icons.photo_camera_outlined,
                        label: 'Foto',
                        selected: _activeView == TicketMediaView.photo,
                        onTap: () =>
                            setState(() => _view = TicketMediaView.photo),
                      ),
                    _MediaChip(
                      icon: Icons.map_outlined,
                      label: 'Hartă',
                      selected: _activeView == TicketMediaView.map,
                      onTap: () => setState(() => _view = TicketMediaView.map),
                    ),
                  ],
                ),
              ),
              if (!widget.compact)
                Flexible(
                  child: Text(
                    ticket.location.display,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: WingmanColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: widget.height,
              width: double.infinity,
              child: _activeView == TicketMediaView.photo && _hasPhoto
                  ? _PhotoView(base64: ticket.photoBase64!)
                  : _TicketMap(
                      ticket: ticket,
                      center: hasCoords
                          ? LatLng(ticket.location.lat!, ticket.location.lng!)
                          : LatLng(config.initialLat, config.initialLng),
                      hasCoords: hasCoords,
                      zoom: hasCoords ? 17 : config.initialZoom,
                      config: config,
                    ),
            ),
          ),
          if (!hasCoords) ...<Widget>[
            const SizedBox(height: 6),
            const Row(
              children: <Widget>[
                Icon(
                  Icons.info_outline,
                  size: 13,
                  color: WingmanColors.pending,
                ),
                SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Fără coordonate GPS pe tichet — harta e centrată pe aeroport.',
                    style: TextStyle(
                      color: WingmanColors.muted,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MediaChip extends StatelessWidget {
  const _MediaChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? WingmanColors.navy : WingmanColors.surfaceMuted,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? WingmanColors.navy : WingmanColors.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 14,
              color: selected ? Colors.white : WingmanColors.muted,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : WingmanColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoView extends StatelessWidget {
  const _PhotoView({required this.base64});

  final String base64;

  @override
  Widget build(BuildContext context) {
    try {
      return Image.memory(
        base64Decode(base64),
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stack) => const _MediaError(
          icon: Icons.broken_image_outlined,
          text: 'Poza nu poate fi afișată.',
        ),
      );
    } on FormatException {
      return const _MediaError(
        icon: Icons.broken_image_outlined,
        text: 'Poza nu poate fi afișată.',
      );
    }
  }
}

class _TicketMap extends StatelessWidget {
  const _TicketMap({
    required this.ticket,
    required this.center,
    required this.hasCoords,
    required this.zoom,
    required this.config,
  });

  final Ticket ticket;
  final LatLng center;
  final bool hasCoords;
  final double zoom;
  final MapConfig config;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: zoom,
            minZoom: 3,
            maxZoom: config.maxZoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: <Widget>[
            TileLayer(
              urlTemplate: config.tileUrl,
              userAgentPackageName: 'com.wingman.wingman',
              maxZoom: config.maxZoom,
              maxNativeZoom: config.maxZoom.toInt(),
            ),
            if (hasCoords)
              MarkerLayer(
                markers: <Marker>[
                  Marker(
                    point: center,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFE11D48),
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            RichAttributionWidget(
              attributions: <SourceAttribution>[
                TextSourceAttribution(
                  config.attribution,
                  prependCopyright: false,
                ),
              ],
            ),
          ],
        ),
        Positioned(
          left: 8,
          right: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: WingmanColors.line),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.place_outlined,
                  size: 14,
                  color: WingmanColors.critical,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    hasCoords
                        ? '${ticket.location.display} · '
                            '${ticket.location.lat!.toStringAsFixed(5)}, '
                            '${ticket.location.lng!.toStringAsFixed(5)}'
                        : ticket.location.display,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: WingmanColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MediaError extends StatelessWidget {
  const _MediaError({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: WingmanColors.surfaceMuted,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 30, color: WingmanColors.muted),
            const SizedBox(height: 6),
            Text(
              text,
              style: const TextStyle(color: WingmanColors.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
