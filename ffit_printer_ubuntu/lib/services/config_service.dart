import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/printer_config.dart';

/// Saves & loads printer config from:
///   ~/.config/ffit/printer.json   (primary, read by CUPS backend too)
///   SharedPreferences             (Flutter fallback)
class ConfigService {
  static const _prefsKey = 'ffit_printer_config';
  static const _configDir = '.config/ffit';
  static const _configFile = 'printer.json';

  PrinterConfig? _current;
  PrinterConfig? get current => _current;

  /// Load from file (and prefs as fallback)
  Future<PrinterConfig?> load() async {
    try {
      final file = await _getConfigFile();
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString());
        _current = PrinterConfig.fromJson(json);
        return _current;
      }
    } catch (_) {}

    // Fallback: SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        _current = PrinterConfig.fromJson(jsonDecode(raw));
        return _current;
      }
    } catch (_) {}

    return null;
  }

  /// Save to ~/.config/ffit/printer.json
  Future<void> save(PrinterConfig config) async {
    _current = config;
    final json = jsonEncode(config.toJson());

    // Write to file (for CUPS backend to read)
    try {
      final file = await _getConfigFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(json);
    } catch (_) {}

    // Write to system-wide file (for CUPS backend to read as lp user)
    try {
      final sysFile = File('/etc/ffit/printer.json');
      await sysFile.writeAsString(json);
    } catch (_) {}

    // Also to prefs
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, json);
    } catch (_) {}
  }

  Future<void> clear() async {
    _current = null;
    try {
      final file = await _getConfigFile();
      if (await file.exists()) await file.delete();
    } catch (_) {}
    try {
      final sysFile = File('/etc/ffit/printer.json');
      if (await sysFile.exists()) await sysFile.delete();
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
  }

  Future<File> _getConfigFile() async {
    final home = Platform.environment['HOME'] ??
        (await getApplicationSupportDirectory()).path;
    return File('$home/$_configDir/$_configFile');
  }

  /// Path shown to user in settings
  Future<String> configPath() async {
    final file = await _getConfigFile();
    return file.path;
  }
}
