import 'package:flutter/material.dart';
import '../models/printer_config.dart';
import '../theme/app_theme.dart';

/// Single discovered printer tile in the discovery list.
/// Non-printers (likelyPrinter = false) are shown greyed-out and non-tappable.
class PrinterTile extends StatelessWidget {
  final DiscoveredPrinter printer;
  final VoidCallback onConnect;       // called for printers
  final VoidCallback? onNotPrinter;   // called for non-printers (optional)

  const PrinterTile({
    super.key,
    required this.printer,
    required this.onConnect,
    this.onNotPrinter,
  });

  @override
  Widget build(BuildContext context) {
    final selectable = printer.isSelectable;
    final color      = selectable ? _typeColor(printer.type) : FFitTheme.textSub;

    // Tap handler: printers → connect, non-printers → show info dialog
    final tapHandler = selectable
        ? onConnect
        : (onNotPrinter ?? () => _showBlockedInfo(context));

    return Opacity(
      opacity: selectable ? 1.0 : 0.45,   // greyed-out for non-printers
      child: GestureDetector(
        onTap: tapHandler,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:        selectable ? FFitTheme.surface : FFitTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selectable ? FFitTheme.border : FFitTheme.border.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              // Type icon — with lock badge for non-printers
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: selectable ? 0.12 : 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(_typeIcon(printer.type), color: color, size: 22),
                    ),
                  ),
                  // 🔴 "Not a printer" badge on top-right
                  if (!printer.likelyPrinter)
                    Positioned(
                      right: -4, top: -4,
                      child: Container(
                        width: 18, height: 18,
                        decoration: const BoxDecoration(
                          color: FFitTheme.error,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.block_rounded,
                          color: Colors.white,
                          size: 11,
                        ),
                      ),
                    ),
                  // ⚠️ Permission badge
                  if (printer.likelyPrinter && !printer.writable)
                    Positioned(
                      right: -4, top: -4,
                      child: Container(
                        width: 18, height: 18,
                        decoration: const BoxDecoration(
                          color: FFitTheme.warning,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),

              // Name + address + reason
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      printer.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 14,
                        color: selectable
                            ? FFitTheme.textPrimary
                            : FFitTheme.textSub,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      printer.displayAddress,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Show reason if disabled
                    if (printer.disabledReason != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        printer.disabledReason!,
                        style: TextStyle(
                          color: printer.likelyPrinter
                              ? FFitTheme.warning
                              : FFitTheme.error,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ],
                ),
              ),

              // Right arrow (only for selectable) OR block icon
              if (selectable)
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_forward_ios_rounded,
                      color: color, size: 14),
                )
              else
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: FFitTheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.block_rounded,
                      color: FFitTheme.error, size: 16),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _typeIcon(ConnectionType t) {
    switch (t) {
      case ConnectionType.usb:       return Icons.usb_rounded;
      case ConnectionType.network:   return Icons.wifi_rounded;
      case ConnectionType.bluetooth: return Icons.bluetooth_rounded;
    }
  }

  Color _typeColor(ConnectionType t) {
    switch (t) {
      case ConnectionType.usb:       return FFitTheme.usbColor;
      case ConnectionType.network:   return FFitTheme.netColor;
      case ConnectionType.bluetooth: return FFitTheme.btColor;
    }
  }

  void _showBlockedInfo(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: FFitTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.block_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '"${printer.name}" printer nahi hai — select nahi ho sakta',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
