import 'dart:io';
import 'dart:typed_data';
import '../models/printer_config.dart';


/// Handles raw byte sending to the printer over USB / Network / Bluetooth.
/// Mirrors the Android BluetoothPrinter.kt — same ESC/POS bytes, different transport.
class PrinterService {
  Socket? _networkSocket;
  IOSink? _usbSink;
  String? _usePath;       // /dev/usb/lp* path
  bool _useRootPipe = false; // true = use pkexec cat pipe for sending
  bool _connected = false;

  bool get isConnected => _connected;

  // ─── Connect ─────────────────────────────────────────────────────────────

  Future<bool> connect(PrinterConfig config) async {
    await disconnect();
    switch (config.type) {
      case ConnectionType.usb:
        return _connectUsb(config);
      case ConnectionType.network:
        return _connectNetwork(config);
      case ConnectionType.bluetooth:
        return _connectBluetooth(config);
    }
  }

  // ─── USB Connect ─────────────────────────────────────────────────────────
  //
  // Flow:
  //  1. Device exists?  → No  → clear error
  //  2. Already writable? → Yes → open directly (user already in lp group)
  //  3. Not writable   → pkexec: ask system password via GUI dialog
  //                      → chmod a+rw  (current session — immediate fix)
  //                      → usermod -aG lp $USER (permanent — next login)
  //  4. After pkexec success → open file directly → connected ✅
  //  5. pkexec cancelled/failed → throw clear error

  Future<bool> _connectUsb(PrinterConfig config) async {
    final path = config.devicePath;

    if (path != null) {
      // ── Step 1: device must exist ──────────────────────────────────────
      if (!await File(path).exists()) {
        throw Exception(
          'USB Printer nahi mila: $path\n'
          'Kya printer USB cable se lagaya hai aur ON hai?',
        );
      }

      // ── Step 2: already writable? ──────────────────────────────────────
      if (await _isWritable(path)) {
        return _openUsbDirect(path);
      }

      // ── Step 3: permission nahi — pkexec se system password lo ─────────
      //    pkexec automatically polkit GUI dialog dikhata hai
      final user = Platform.environment['USER'] ??
                   Platform.environment['LOGNAME'] ??
                   'ubuntu_16gb';

      final permResult = await Process.run(
        'pkexec',
        [
          'bash', '-c',
          // a) current session ke liye device writable banao
          'chmod a+rw $path && '
          // b) permanently user ko lp group mein daalo
          'usermod -aG lp $user && '
          // c) udev rule install karo (future USB connections ke liye)
          'bash -c \'echo "KERNEL=\\"lp[0-9]*\\", SUBSYSTEMS==\\"usb\\", DRIVERS==\\"usblp\\", MODE=\\"0666\\", GROUP=\\"lp\\"" > /etc/udev/rules.d/99-ffit-printer.rules\' && '
          'udevadm control --reload-rules',
        ],
        runInShell: false,
      ).timeout(const Duration(seconds: 30));

      if (permResult.exitCode != 0) {
        // User ne cancel kiya ya password galat tha
        throw Exception(
          'Permission fix cancelled ya fail hua.\n'
          'Print karne ke liye system password zaroori hai.\n'
          'Ya terminal mein chalaao:\n'
          '  sudo usermod -aG lp \$USER\n'
          '  sudo chmod a+rw $path',
        );
      }

      // ── Step 4: ab writable hona chahiye — open karo ──────────────────
      return _openUsbDirect(path);
    }

    // CUPS queue fallback
    if (config.cupsName != null) {
      _connected = true;
      return true;
    }
    return false;
  }

  /// Check if device file is writable in current session
  Future<bool> _isWritable(String path) async {
    try {
      final r = await Process.run(
        'bash', ['-c', 'test -w "\$1" && echo ok', '--', path],
        runInShell: false,
      ).timeout(const Duration(seconds: 3));
      return r.stdout.toString().trim() == 'ok';
    } catch (_) {
      return false;
    }
  }

  /// Open USB device file for direct byte writing
  Future<bool> _openUsbDirect(String path) async {
    try {
      // Test write-open and close immediately so device is not locked
      final sink = File(path).openWrite(mode: FileMode.writeOnly);
      await sink.close();
      
      _usbSink     = null; 
      _connected   = true;
      _usePath     = path;
      _useRootPipe = false;
      return true;
    } catch (e) {
      throw Exception(
        'USB device open nahi ho raha: $path\n'
        'Error: $e\n'
        'Printer replug karo aur dobara try karo.',
      );
    }
  }

  // Network — TCP socket to IP:9100
  Future<bool> _connectNetwork(PrinterConfig config) async {
    try {
      _networkSocket = await Socket.connect(
        config.host!,
        config.port,
        timeout: const Duration(seconds: 6),
      );
      _connected = true;
      return true;
    } catch (e) {
      _connected = false;
      rethrow;
    }
  }

  // Bluetooth — RFCOMM via dart:io RawSocket (AF_BLUETOOTH = 31)
  Future<bool> _connectBluetooth(PrinterConfig config) async {
    // Note: Dart doesn't have native BT support.
    // We use rfcomm bind + open as file descriptor (Linux-specific).
    try {
      final mac = config.macAddress!;
      final channel = config.btChannel;

      // Use rfcomm to create a virtual serial port
      final bindResult = await Process.run('rfcomm', [
        'bind', '/dev/rfcomm0', mac, channel.toString()
      ]);

      if (bindResult.exitCode != 0 &&
          !bindResult.stderr.toString().contains('already')) {
        throw Exception('rfcomm bind failed: ${bindResult.stderr}');
      }

      // Small delay for device to appear
      await Future.delayed(const Duration(milliseconds: 500));

      final file = File('/dev/rfcomm0');
      // Test opening and closing
      final sink = file.openWrite(mode: FileMode.writeOnly);
      await sink.close();
      
      _usbSink = null;
      _usePath = '/dev/rfcomm0';
      _connected = true;
      return true;
    } catch (e) {
      _connected = false;
      rethrow;
    }
  }

  // ─── Send raw bytes ──────────────────────────────────────────────────────

  Future<bool> send(Uint8List data, {PrinterConfig? config}) async {
    if (!_connected) return false;
    try {
      if (_networkSocket != null) {
        _networkSocket!.add(data);
        await _networkSocket!.flush();
        return true;
      }
      if (_usbSink != null) {
        _usbSink!.add(data);
        await _usbSink!.flush();
        return true;
      }
      // If we have a path to a direct file (USB or BT rfcomm serial port), open, write, and close it
      if (_usePath != null && !_useRootPipe) {
        final file = File(_usePath!);
        final sink = file.openWrite(mode: FileMode.writeOnly);
        sink.add(data);
        await sink.flush();
        await sink.close();
        return true;
      }
      // Root pipe fallback (when direct write failed due to permissions)
      if (_useRootPipe && _usePath != null) {
        return _sendViaPipe(data, _usePath!);
      }
      // CUPS fallback
      if (config?.cupsName != null) {
        return _sendViaCups(data, config!.cupsName!);
      }
      return false;
    } catch (e) {
      // Don't mark disconnected immediately if it was just a temporary print error,
      // but let's keep it safe.
      return false;
    }
  }

  /// Send data via pkexec tee (writes as root, no GUI if polkit cached)
  Future<bool> _sendViaPipe(Uint8List data, String devicePath) async {
    final tmpFile = File('/tmp/ffit_usb_${DateTime.now().millisecondsSinceEpoch}.bin');
    try {
      await tmpFile.writeAsBytes(data);

      // Try: pkexec tee /dev/usb/lp0 < tmpfile
      final r = await Process.run(
        'bash',
        ['-c', 'pkexec tee $devicePath < ${tmpFile.path} > /dev/null'],
      ).timeout(const Duration(seconds: 15));

      if (r.exitCode == 0) return true;

      // Fallback: sudo -n tee (no password)
      final r2 = await Process.run(
        'bash',
        ['-c', 'sudo -n tee $devicePath < ${tmpFile.path} > /dev/null'],
      ).timeout(const Duration(seconds: 5));

      return r2.exitCode == 0;
    } finally {
      try { await tmpFile.delete(); } catch (_) {}
    }
  }

  Future<bool> _sendViaCups(Uint8List data, String queueName) async {
    final tmpFile = File('/tmp/ffit_print_${DateTime.now().millisecondsSinceEpoch}.bin');
    try {
      await tmpFile.writeAsBytes(data);
      final result = await Process.run('lp', [
        '-d', queueName,
        '-o', 'raw',
        tmpFile.path,
      ]);
      return result.exitCode == 0;
    } finally {
      if (await tmpFile.exists()) await tmpFile.delete();
    }
  }

  // ─── Disconnect ──────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    _connected  = false;
    _useRootPipe = false;
    _usePath    = null;
    try {
      await _usbSink?.flush();
      await _usbSink?.close();
    } catch (_) {}
    _usbSink = null;

    try {
      await _networkSocket?.flush();
      await _networkSocket?.close();
    } catch (_) {}
    _networkSocket = null;

    // Release rfcomm if bound
    try {
      await Process.run('rfcomm', ['release', '/dev/rfcomm0']);
    } catch (_) {}
  }
}
