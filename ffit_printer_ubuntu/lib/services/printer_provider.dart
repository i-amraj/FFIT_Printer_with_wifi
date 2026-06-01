import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/printer_config.dart';
import '../services/config_service.dart';
import '../services/printer_service.dart';
import '../services/escpos_service.dart';
import '../services/discovery_service.dart';

enum AppState { idle, scanning, connecting, printing, error }

/// Central app state — consumed by all screens via Provider
class PrinterProvider extends ChangeNotifier {
  final _config     = ConfigService();
  final _printer    = PrinterService();
  final _discovery  = DiscoveryService();

  PrinterConfig? get savedConfig   => _config.current;
  bool           get isConnected   => _printer.isConnected;

  AppState _state = AppState.idle;
  AppState get state => _state;

  String _statusMessage = '';
  String get statusMessage => _statusMessage;

  bool _hasError = false;
  bool get hasError => _hasError;

  // Discovered printers lists
  List<DiscoveredPrinter> _usbPrinters  = [];
  List<DiscoveredPrinter> _netPrinters  = [];
  List<DiscoveredPrinter> _btPrinters   = [];

  List<DiscoveredPrinter> get usbPrinters  => _usbPrinters;
  List<DiscoveredPrinter> get netPrinters  => _netPrinters;
  List<DiscoveredPrinter> get btPrinters   => _btPrinters;

  List<DiscoveredPrinter> get allPrinters =>
      [..._usbPrinters, ..._netPrinters, ..._btPrinters];

  // ─── Init ────────────────────────────────────────────────────────────────

  Future<void> init() async {
    await _config.load();
    notifyListeners();

    // Auto-reconnect for Network only (USB needs permission, BT needs pair)
    final cfg = savedConfig;
    if (cfg != null && cfg.type == ConnectionType.network) {
      try {
        await _printer.connect(cfg);
        if (_printer.isConnected) {
          _statusMessage = 'Reconnected to ${cfg.name}';
        }
        notifyListeners();
      } catch (_) {
        // Silent fail on startup — user can reconnect manually
        _statusMessage = 'Last printer: ${cfg.name} (tap Find Printer to connect)';
        notifyListeners();
      }
    } else if (cfg != null) {
      _statusMessage = 'Last printer: ${cfg.name} (tap Find Printer to reconnect)';
      notifyListeners();
    }
  }

  // ─── Discovery ───────────────────────────────────────────────────────────

  Future<void> scanAll() async {
    _state = AppState.scanning;
    _usbPrinters  = [];
    _netPrinters  = [];
    _btPrinters   = [];
    _statusMessage = 'Scanning…';
    _hasError = false;
    notifyListeners();

    try {
      // Run USB + Network concurrently, BT takes longer
      final usbFut = _discovery.discoverUsb();
      final netFut = _discovery.discoverNetwork(
        onFound: (p) {
          _netPrinters.add(p);
          notifyListeners();
        },
      );

      final results = await Future.wait([usbFut, netFut]);
      _usbPrinters = results[0];
      _netPrinters = results[1];

      _statusMessage = '${allPrinters.length} printer(s) found';
      _state = AppState.idle;
      notifyListeners();
    } catch (e) {
      _state = AppState.error;
      _hasError = true;
      _statusMessage = 'Scan error: $e';
      notifyListeners();
    }
  }

  Future<void> scanBluetooth() async {
    _state = AppState.scanning;
    _btPrinters = [];
    _statusMessage = 'Scanning Bluetooth (8s)…';
    notifyListeners();

    try {
      _btPrinters = await _discovery.discoverBluetooth(
        onFound: (p) {
          if (!_btPrinters.any((x) => x.address == p.address)) {
            _btPrinters.add(p);
          }
          notifyListeners();
        },
      );
      _statusMessage = '${_btPrinters.length} BT device(s) found';
    } catch (e) {
      _statusMessage = 'BT scan error: $e';
      _hasError = true;
    }

    _state = AppState.idle;
    notifyListeners();
  }

  // ─── Connect ─────────────────────────────────────────────────────────────

  Future<bool> connect(PrinterConfig config) async {
    _state = AppState.connecting;
    // USB pe pehli baar connect karne par password dialog aata hai
    _statusMessage = config.type == ConnectionType.usb
        ? 'USB Printer se connect ho raha hai…\n(Agar permission nahi hai to system password dialog aayega)'
        : 'Connecting to ${config.name}…';
    _hasError = false;
    notifyListeners();

    try {
      final ok = await _printer.connect(config);
      if (ok) {
        await _config.save(config);
        _statusMessage = 'Connected to ${config.name}';
        _state = AppState.idle;
      } else {
        _statusMessage = 'Could not connect to ${config.name}';
        _hasError = true;
        _state = AppState.error;
      }
      notifyListeners();
      return ok;
    } on Exception catch (e) {
      // Clean error message (strip "Exception: " prefix)
      final msg = e.toString().replaceFirst('Exception: ', '');
      _statusMessage = msg;
      _hasError = true;
      _state = AppState.error;
      notifyListeners();
      return false;
    } catch (e) {
      _statusMessage = 'Error: $e';
      _hasError = true;
      _state = AppState.error;
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    await _printer.disconnect();
    _statusMessage = 'Disconnected';
    notifyListeners();
  }

  // ─── Test Print ──────────────────────────────────────────────────────────

  Future<bool> testPrint() async {
    if (!isConnected || savedConfig == null) {
      _statusMessage = 'No printer connected';
      _hasError = true;
      notifyListeners();
      return false;
    }

    _state = AppState.printing;
    _statusMessage = 'Sending test page…';
    _hasError = false;
    notifyListeners();

    try {
      final bytes = buildTestReceipt(
          paperWidthMm: savedConfig!.paperWidthMm);
      final ok = await _printer.send(bytes, config: savedConfig);

      _statusMessage = ok ? '✅ Test page printed!' : '❌ Print failed';
      _hasError = !ok;
      _state = AppState.idle;
      notifyListeners();
      return ok;
    } catch (e) {
      _statusMessage = 'Print error: $e';
      _hasError = true;
      _state = AppState.error;
      notifyListeners();
      return false;
    }
  }

  // ─── CUPS Registration ───────────────────────────────────────────────────

  Future<bool> registerWithCups() async {
    final cfg = savedConfig;
    if (cfg == null) return false;

    _statusMessage = 'Registering with CUPS…';
    notifyListeners();

    try {
      final uri = _buildCupsUri(cfg);
      final result = await Process.run('lpadmin', [
        '-p', 'FFit-Thermal',
        '-E',
        '-v', uri,
        '-P', '/usr/share/ppd/custom/pos58.ppd',
        '-D', cfg.name,
        '-L', 'FFit Thermal Printer',
      ], runInShell: true);

      if (result.exitCode == 0) {
        _statusMessage = 'CUPS printer "FFit-Thermal" registered ✅';
        notifyListeners();
        return true;
      } else {
        _statusMessage = 'CUPS registration failed: ${result.stderr}';
        _hasError = true;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _statusMessage = 'CUPS error: $e';
      _hasError = true;
      notifyListeners();
      return false;
    }
  }

  String _buildCupsUri(PrinterConfig cfg) {
    switch (cfg.type) {
      case ConnectionType.usb:
        return 'ffit://usb${cfg.devicePath ?? ''}';
      case ConnectionType.network:
        return 'ffit://network/${cfg.host}:${cfg.port}';
      case ConnectionType.bluetooth:
        return 'ffit://bluetooth/${cfg.macAddress}';
    }
  }

  // ─── Paper size toggle ───────────────────────────────────────────────────

  Future<void> setPaperWidth(PaperWidth width) async {
    if (savedConfig == null) return;
    final updated = savedConfig!.copyWith(paperWidth: width);
    await _config.save(updated);
    notifyListeners();
  }

  Future<String> get configPath => _config.configPath();
}
