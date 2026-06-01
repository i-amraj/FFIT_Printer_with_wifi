/// Printer config model — saved to ~/.config/ffit/printer.json
/// Mirrors the SharedPreferences keys used in Android PrinterPrefs.kt

enum ConnectionType { usb, network, bluetooth }

enum PaperWidth { mm58, mm80 }

class PrinterConfig {
  final ConnectionType type;
  final String name;

  // USB
  final String? devicePath;   // e.g. /dev/usb/lp0
  final String? cupsName;     // e.g. FFit-Thermal-58mm

  // Network
  final String? host;         // IP address
  final int port;             // default 9100

  // Bluetooth
  final String? macAddress;   // e.g. 00:11:22:33:44:55
  final int btChannel;        // RFCOMM channel, default 1

  // Print settings
  final PaperWidth paperWidth;

  const PrinterConfig({
    required this.type,
    required this.name,
    this.devicePath,
    this.cupsName,
    this.host,
    this.port = 9100,
    this.macAddress,
    this.btChannel = 1,
    this.paperWidth = PaperWidth.mm58,
  });

  int get printWidthPx => 384;
  int get paperWidthMm => 58;

  String get displayAddress {
    switch (type) {
      case ConnectionType.usb:
        return devicePath ?? cupsName ?? 'USB';
      case ConnectionType.network:
        return '$host:$port';
      case ConnectionType.bluetooth:
        return macAddress ?? 'Unknown';
    }
  }

  String get typeLabel {
    switch (type) {
      case ConnectionType.usb:       return 'USB';
      case ConnectionType.network:   return 'Network';
      case ConnectionType.bluetooth: return 'Bluetooth';
    }
  }

  Map<String, dynamic> toJson() => {
    'type':        type.name,
    'name':        name,
    'device_path': devicePath,
    'cups_name':   cupsName,
    'host':        host,
    'port':        port,
    'mac_address': macAddress,
    'bt_channel':  btChannel,
    'paper_width': paperWidth.name,
  };

  factory PrinterConfig.fromJson(Map<String, dynamic> j) => PrinterConfig(
    type:        ConnectionType.values.firstWhere(
                   (e) => e.name == j['type'],
                   orElse: () => ConnectionType.network),
    name:        j['name'] ?? 'Printer',
    devicePath:  j['device_path'],
    cupsName:    j['cups_name'],
    host:        j['host'],
    port:        j['port'] ?? 9100,
    macAddress:  j['mac_address'],
    btChannel:   j['bt_channel'] ?? 1,
    paperWidth:  PaperWidth.values.firstWhere(
                   (e) => e.name == j['paper_width'],
                   orElse: () => PaperWidth.mm58),
  );

  PrinterConfig copyWith({
    ConnectionType? type,
    String? name,
    String? devicePath,
    String? cupsName,
    String? host,
    int? port,
    String? macAddress,
    int? btChannel,
    PaperWidth? paperWidth,
  }) =>
      PrinterConfig(
        type:        type        ?? this.type,
        name:        name        ?? this.name,
        devicePath:  devicePath  ?? this.devicePath,
        cupsName:    cupsName    ?? this.cupsName,
        host:        host        ?? this.host,
        port:        port        ?? this.port,
        macAddress:  macAddress  ?? this.macAddress,
        btChannel:   btChannel   ?? this.btChannel,
        paperWidth:  paperWidth  ?? this.paperWidth,
      );
}

/// A discovered (not yet configured) printer found during scan
class DiscoveredPrinter {
  final ConnectionType type;
  final String name;
  final String address;   // IP, MAC, or /dev/usb/lp*
  final String? cupsName; // CUPS queue name (if from CUPS)
  final int port;
  final bool likelyPrinter;
  final bool writable;    // false = permission denied

  const DiscoveredPrinter({
    required this.type,
    required this.name,
    required this.address,
    this.cupsName,
    this.port = 9100,
    this.likelyPrinter = true,
    this.writable = true,
  });

  /// True = user can tap and connect
  bool get isSelectable => likelyPrinter;

  /// Reason why not selectable (shown as subtitle hint)
  String? get disabledReason {
    if (!likelyPrinter) return 'Printer nahi lag raha — select nahi ho sakta';
    if (!writable) return 'Permission nahi hai — sudo usermod -aG lp \$USER';
    return null;
  }

  String get typeIcon {
    switch (type) {
      case ConnectionType.usb:       return '\u{1F5A8}';
      case ConnectionType.network:   return '\u{1F310}';
      case ConnectionType.bluetooth: return '\u{1F4F6}';
    }
  }

  String get displayAddress {
    switch (type) {
      case ConnectionType.usb:       return cupsName ?? address;
      case ConnectionType.network:   return '$address:$port';
      case ConnectionType.bluetooth: return address;
    }
  }

  PrinterConfig toConfig() => PrinterConfig(
    type:       type,
    name:       name,
    devicePath: (type == ConnectionType.usb && cupsName == null) ? address : null,
    cupsName:   cupsName,
    host:       type == ConnectionType.network ? address : null,
    port:       port,
    macAddress: type == ConnectionType.bluetooth ? address : null,
  );
}
