import 'dart:io';
import 'dart:async';
import '../models/printer_config.dart';

/// Scans the system for available printers (USB, Network, Bluetooth)
class DiscoveryService {

  // ─── USB Discovery ─────────────────────────────────────────────────────



  Future<List<DiscoveredPrinter>> discoverUsb() async {
    final results = <DiscoveredPrinter>[];

    // ONLY /dev/usb/lp* — Linux kernel ye files SIRF tab banata hai
    // jab koi USB device "Printing Class" (bClass=0x07) declare kare.
    // Iska matlab: ye GUARANTEED thermal / label / inkjet printers hain.
    // CUPS queues yahan NAHI dikhate — wo System tab mein alag hote hain.
    for (int i = 0; i < 8; i++) {
      final path = '/dev/usb/lp$i';
      if (await File(path).exists()) {
        final writable    = await _checkWritable(path);
        final displayName = await _getUsbPrinterName(i);

        results.add(DiscoveredPrinter(
          type:          ConnectionType.usb,
          name:          displayName,
          address:       path,
          likelyPrinter: true,   // /dev/usb/lp* = 100% confirmed printer
          writable:      writable,
        ));
      }
    }

    return results;
  }

  /// Printer ka real naam sysfs ya lsusb se padho
  Future<String> _getUsbPrinterName(int lpNum) async {
    try {
      // Method 1: sysfs product file
      for (final tmpl in [
        '/sys/class/usbmisc/lp$lpNum/device/../product',
        '/sys/class/usb/lp$lpNum/device/product',
      ]) {
        // Resolve the `..` in path using shell
        final r = await Process.run('cat', [tmpl], runInShell: true)
            .timeout(const Duration(seconds: 2));
        final name = r.stdout.toString().trim();
        if (name.isNotEmpty && r.exitCode == 0) return name;
      }

      // Method 2: lsusb — printer class 07
      final r = await Process.run(
        'bash', ['-c', 'lsusb -v 2>/dev/null | grep -A5 "bDeviceClass.*0x07\|bInterfaceClass.*0x07" | grep "iProduct\|idProduct" | head -1'],
        runInShell: true,
      ).timeout(const Duration(seconds: 4));
      final line = r.stdout.toString().trim();
      if (line.isNotEmpty) {
        final m = RegExp(r'\s+(.+)$').firstMatch(line);
        if (m != null) return m.group(1)!.trim();
      }
    } catch (_) {}

    return 'USB Printer (lp$lpNum)';
  }

  // ─── Network Discovery ──────────────────────────────────────────────────

  Future<ActiveNetworkInfo?> getActiveNetworkInfo() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
              return ActiveNetworkInfo(
                interfaceName: iface.name,
                ipAddress: addr.address,
                subnetPrefix: prefix,
              );
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<List<DiscoveredPrinter>> discoverNetwork({
    String? subnetPrefix,
    int? port,
    int? startIp,
    int? endIp,
    void Function(DiscoveredPrinter)? onFound,
  }) async {
    final results = <DiscoveredPrinter>[];

    // 1. avahi / mDNS
    try {
      final r = await Process.run(
        'avahi-browse', ['-t', '-r', '-p', '_pdl-datastream._tcp'],
        runInShell: true,
      ).timeout(const Duration(seconds: 10));

      for (final line in r.stdout.toString().split('\n')) {
        final parts = line.split(';');
        if (parts.length >= 9 && parts[0] == '=') {
          final host  = parts[6];
          final pPort  = int.tryParse(parts[8]) ?? 9100;
          final name  = parts[3].isNotEmpty ? parts[3] : host;

          if (port != null && pPort != port) continue;
          if (subnetPrefix != null && !host.startsWith(subnetPrefix)) continue;

          final p = DiscoveredPrinter(
            type: ConnectionType.network,
            name: name,
            address: host,
            port: pPort,
          );
          results.add(p);
          onFound?.call(p);
        }
      }
    } catch (_) {}

    // 2. Subnet scan
    if (results.isEmpty || subnetPrefix != null) {
      final found = await _scanSubnet9100(
        subnetPrefix: subnetPrefix,
        port: port ?? 9100,
        startIp: startIp ?? 1,
        endIp: endIp ?? 254,
        onFound: onFound,
      );
      for (final p in found) {
        if (!results.any((x) => x.address == p.address && x.port == p.port)) {
          results.add(p);
        }
      }
    }

    return results;
  }

  Future<List<DiscoveredPrinter>> _scanSubnet9100({
    String? subnetPrefix,
    required int port,
    required int startIp,
    required int endIp,
    void Function(DiscoveredPrinter)? onFound,
  }) async {
    final results = <DiscoveredPrinter>[];

    String? subnet = subnetPrefix;
    if (subnet == null) {
      // Detect local IP
      String? localIp;
      try {
        final interfaces = await NetworkInterface.list();
        final candidates = <String>[];
        for (final iface in interfaces) {
          for (final addr in iface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
              candidates.add(addr.address);
            }
          }
        }
        if (candidates.isNotEmpty) {
          // Find private IP address first
          localIp = candidates.firstWhere(
            (ip) => ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.'),
            orElse: () => candidates.first,
          );
        }
      } catch (_) {}

      if (localIp != null) {
        final parts = localIp.split('.');
        if (parts.length >= 3) {
          subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
        }
      }
    }

    if (subnet == null) return results;

    final lock = <DiscoveredPrinter>[];
    
    // Chunked parallel TCP probe of startIp to endIp on user configured port
    const chunkCount = 32;
    for (int chunk = startIp - 1; chunk < endIp; chunk += chunkCount) {
      final chunkFutures = <Future>[];
      for (int i = chunk + 1; i <= chunk + chunkCount && i <= endIp && i <= 254; i++) {
        final ip = '$subnet.$i';
        chunkFutures.add(() async {
          try {
            final s = await Socket.connect(
              ip, port,
              timeout: const Duration(milliseconds: 500),
            );
            s.destroy();
            final p = DiscoveredPrinter(
              type:    ConnectionType.network,
              name:    'Thermal Printer @ $ip',
              address: ip,
              port:    port,
            );
            lock.add(p);
            onFound?.call(p);
          } catch (_) {}
        }());
      }
      await Future.wait(chunkFutures);
    }

    results.addAll(lock);
    return results;
  }

  // ─── Bluetooth Discovery ────────────────────────────────────────────────

  Future<List<DiscoveredPrinter>> discoverBluetooth({
    void Function(DiscoveredPrinter)? onFound,
  }) async {
    final results = <DiscoveredPrinter>[];
    final printerKeywords = [
      'printer', 'print', 'pos', 'thermal', 'receipt',
      'rpp', 'hop', 'xp-', 'mtp', 'zj-', 'pt-',
    ];

    // Use bluetoothctl scan (most reliable on modern Ubuntu)
    try {
      // Start scan for 8 seconds
      final proc = await Process.start('bluetoothctl', []);
      proc.stdin.writeln('scan on');
      await Future.delayed(const Duration(seconds: 8));
      proc.stdin.writeln('devices');
      await Future.delayed(const Duration(milliseconds: 500));
      proc.stdin.writeln('scan off');
      proc.stdin.writeln('exit');

      final output = await proc.stdout
          .transform(const SystemEncoding().decoder)
          .join();

      // Parse "Device XX:XX:XX:XX:XX:XX Name" lines
      final devicePattern = RegExp(r'Device\s+([0-9A-Fa-f:]{17})\s+(.+)');
      for (final match in devicePattern.allMatches(output)) {
        final mac  = match.group(1)!;
        final name = match.group(2)!.trim();
        final likely = printerKeywords.any((k) => name.toLowerCase().contains(k));
        final p = DiscoveredPrinter(
          type:          ConnectionType.bluetooth,
          name:          name,
          address:       mac,
          likelyPrinter: likely,
        );
        results.add(p);
        onFound?.call(p);
      }
    } catch (_) {
      // Fallback: hcitool scan
      try {
        final r = await Process.run('hcitool', ['scan'], runInShell: true)
            .timeout(const Duration(seconds: 12));
        for (final line in r.stdout.toString().split('\n').skip(1)) {
          final parts = line.trim().split('\t');
          if (parts.length >= 2) {
            final mac  = parts[0].trim();
            final name = parts[1].trim();
            final likely = printerKeywords.any((k) => name.toLowerCase().contains(k));
            final p = DiscoveredPrinter(
              type:          ConnectionType.bluetooth,
              name:          name,
              address:       mac,
              likelyPrinter: likely,
            );
            results.add(p);
            onFound?.call(p);
          }
        }
      } catch (_) {}
    }

    // Sort: likely printers first
    results.sort((a, b) => b.likelyPrinter ? 1 : -1);
    return results;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Try to open the file for writing to check write permission.
  /// Returns true if writable, false if permission denied.
  Future<bool> _checkWritable(String path) async {
    try {
      final result = await Process.run(
        'test', ['-w', path], runInShell: true,
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}

class ActiveNetworkInfo {
  final String interfaceName;
  final String ipAddress;
  final String subnetPrefix;

  const ActiveNetworkInfo({
    required this.interfaceName,
    required this.ipAddress,
    required this.subnetPrefix,
  });
}
