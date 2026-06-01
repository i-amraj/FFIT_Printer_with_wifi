import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Animated status dot — green pulsing when connected, red when not
class StatusBadge extends StatefulWidget {
  final bool connected;
  final bool loading;
  const StatusBadge({super.key, required this.connected, this.loading = false});

  @override
  State<StatusBadge> createState() => _StatusBadgeState();
}

class _StatusBadgeState extends State<StatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const SizedBox(
        width: 48, height: 48,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: FFitTheme.accent,
        ),
      );
    }

    final color = widget.connected ? FFitTheme.success : FFitTheme.error;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final pulse = widget.connected ? _pulse.value : 0.0;
        return Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.1 + pulse * 0.1),
            boxShadow: [
              BoxShadow(
                color:       color.withOpacity(0.2 + pulse * 0.2),
                blurRadius:  12 + pulse * 8,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 14, height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
          ),
        );
      },
    );
  }
}
