import 'package:flutter/material.dart';

/// Short entrance animation when a ticket card appears in the feed.
class AnimatedTicketItem extends StatefulWidget {
  const AnimatedTicketItem({
    super.key,
    required this.child,
    required this.itemKey,
  });

  final Widget child;
  final String itemKey;

  @override
  State<AnimatedTicketItem> createState() => _AnimatedTicketItemState();
}

class _AnimatedTicketItemState extends State<AnimatedTicketItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  String? _playedFor;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _playIfNeeded();
  }

  @override
  void didUpdateWidget(covariant AnimatedTicketItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemKey != widget.itemKey) {
      _playIfNeeded(force: true);
    }
  }

  void _playIfNeeded({bool force = false}) {
    if (!force && _playedFor == widget.itemKey) return;
    _playedFor = widget.itemKey;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
