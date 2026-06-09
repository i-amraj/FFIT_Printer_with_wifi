import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../services/printer_provider.dart';
import '../theme/app_theme.dart';
import '../models/printer_config.dart';
import '../widgets/printer_tile.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  int _selectedTab = 0;

  final _subnetController = TextEditingController();
  final _portController = TextEditingController(text: '9100');
  final _startIpController = TextEditingController(text: '1');
  final _endIpController = TextEditingController(text: '254');
  bool _showConfig = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      setState(() => _selectedTab = _tabs.index);
    });
    // Auto scan USB + Network on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<PrinterProvider>();
      p.scanAll();
      p.fetchActiveNetworkInfo().then((_) {
        if (p.activeNetInfo != null) {
          _subnetController.text = p.activeNetInfo!.subnetPrefix;
        }
      });
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _subnetController.dispose();
    _portController.dispose();
    _startIpController.dispose();
    _endIpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: FFitTheme.bgGradient),
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(child: _buildTabContent()),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: FFitTheme.textPrimary, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Find Printer',
                  style: Theme.of(context).textTheme.titleLarge),
              Text('Select your connection type',
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          const Spacer(),
          Consumer<PrinterProvider>(
            builder: (_, p, __) => p.state == AppState.scanning
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: FFitTheme.accent),
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh_rounded,
                        color: FFitTheme.accent),
                    onPressed: () => _refresh(),
                    tooltip: 'Refresh',
                  ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.1);
  }

  // ── Tab bar ───────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    final tabs = [
      ('USB', Icons.usb_rounded, FFitTheme.usbColor),
      ('Network', Icons.wifi_rounded, FFitTheme.netColor),
      ('Bluetooth', Icons.bluetooth_rounded, FFitTheme.btColor),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: FFitTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FFitTheme.border),
      ),
      child: TabBar(
        controller: _tabs,
        labelColor: FFitTheme.textPrimary,
        unselectedLabelColor: FFitTheme.textSub,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color:        FFitTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(
            color: tabs[_selectedTab].$3.withOpacity(0.4)),
        ),
        labelStyle: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600),
        tabs: tabs.map((t) => Tab(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(t.$2, size: 16,
                  color: _selectedTab == tabs.indexOf(t)
                      ? t.$3 : FFitTheme.textSub),
              const SizedBox(width: 6),
              Text(t.$1),
            ],
          ),
        )).toList(),
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  // ── Tab content ───────────────────────────────────────────────────────────
  Widget _buildTabContent() {
    return Consumer<PrinterProvider>(
      builder: (_, provider, __) {
        return TabBarView(
          controller: _tabs,
          children: [
            _buildList(provider.usbPrinters, ConnectionType.usb, provider),
            _buildNetTab(provider),
            _buildBtTab(provider),
          ],
        );
      },
    );
  }

  Widget _buildList(List<DiscoveredPrinter> printers,
      ConnectionType type, PrinterProvider provider) {
    if (provider.state == AppState.scanning && printers.isEmpty) {
      return _buildScanning(_labelFor(type));
    }

    if (printers.isEmpty) {
      return _buildEmpty(type);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: printers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final p = printers[i];
        return PrinterTile(
          printer:   p,
          onConnect: () => _connect(p, provider),
          onNotPrinter: p.isSelectable ? null : () => _showNotPrinterDialog(p),
        ).animate().fadeIn(delay: (i * 50).ms).slideX(begin: 0.1, end: 0);
      },
    );
  }

  Widget _buildNetTab(PrinterProvider provider) {
    final active = provider.activeNetInfo;

    return Column(
      children: [
        // Active Network Banner
        if (active != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: FFitTheme.netColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: FFitTheme.netColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: FFitTheme.netColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.wifi_tethering_rounded,
                      color: FFitTheme.netColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Interface: ${active.interfaceName}',
                        style: const TextStyle(
                          color: FFitTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'IP: ${active.ipAddress} | Subnet: ${active.subnetPrefix}.0',
                        style: const TextStyle(
                          color: FFitTheme.textSub,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: -0.1),

        // Controls: Config Toggle + Manual IP
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FFitTheme.textPrimary,
                    side: BorderSide(color: FFitTheme.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: Icon(
                    _showConfig ? Icons.expand_less_rounded : Icons.tune_rounded,
                    size: 16,
                    color: FFitTheme.netColor,
                  ),
                  label: Text(
                    _showConfig ? 'Hide Config' : 'Scanner Config',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () {
                    setState(() => _showConfig = !_showConfig);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FFitTheme.netColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.add_link_rounded, size: 16),
                  label: const Text('Manual IP', style: TextStyle(fontSize: 12)),
                  onPressed: () => _showManualIpDialog(provider),
                ),
              ),
            ],
          ),
        ),

        // Collapsible Scanner settings form
        if (_showConfig)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FFitTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: FFitTheme.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _subnetController,
                        style: const TextStyle(color: FFitTheme.textPrimary, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Subnet Prefix',
                          labelStyle: TextStyle(color: FFitTheme.textSub, fontSize: 11),
                          hintText: '192.168.1',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _portController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: FFitTheme.textPrimary, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Port',
                          labelStyle: TextStyle(color: FFitTheme.textSub, fontSize: 11),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _startIpController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: FFitTheme.textPrimary, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Start IP',
                          labelStyle: TextStyle(color: FFitTheme.textSub, fontSize: 11),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _endIpController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: FFitTheme.textPrimary, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'End IP',
                          labelStyle: TextStyle(color: FFitTheme.textSub, fontSize: 11),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FFitTheme.netColor,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.search_rounded, size: 16),
                    label: const Text('Custom Subnet Scan'),
                    onPressed: () {
                      final prefix = _subnetController.text.trim();
                      final port = int.tryParse(_portController.text.trim()) ?? 9100;
                      final start = int.tryParse(_startIpController.text.trim()) ?? 1;
                      final end = int.tryParse(_endIpController.text.trim()) ?? 254;

                      if (prefix.isNotEmpty) {
                        provider.scanCustomNetwork(
                          subnetPrefix: prefix,
                          port: port,
                          startIp: start,
                          endIp: end,
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: -0.05),

        // Results List
        Expanded(
          child: _buildList(provider.netPrinters, ConnectionType.network, provider),
        ),
      ],
    );
  }

  void _showManualIpDialog(PrinterProvider provider) {
    final nameController = TextEditingController(text: 'ffit-wifi');
    final ipController = TextEditingController();
    final portController = TextEditingController(text: '9100');
    final subnetController = TextEditingController(text: '255.255.255.0');
    final formKey = GlobalKey<FormState>();
    bool loading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: FFitTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: FFitTheme.netColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.wifi_rounded,
                        color: FFitTheme.netColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Manual WiFi Printer'),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        style: const TextStyle(color: FFitTheme.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Printer Name',
                          labelStyle: TextStyle(color: FFitTheme.textSub),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: FFitTheme.netColor),
                          ),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Name is required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: ipController,
                        style: const TextStyle(color: FFitTheme.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'IP Address (e.g. 192.168.1.100)',
                          labelStyle: TextStyle(color: FFitTheme.textSub),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: FFitTheme.netColor),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'IP Address is required';
                          }
                          final clean = v.trim();
                          final regex = RegExp(
                              r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$');
                          if (!regex.hasMatch(clean)) {
                            return 'Enter a valid IP address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: subnetController,
                        style: const TextStyle(color: FFitTheme.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Subnet Mask (e.g. 255.255.255.0)',
                          labelStyle: TextStyle(color: FFitTheme.textSub),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: FFitTheme.netColor),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Subnet Mask is required';
                          }
                          final clean = v.trim();
                          final regex = RegExp(
                              r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$');
                          if (!regex.hasMatch(clean)) {
                            return 'Enter a valid Subnet Mask';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: portController,
                        style: const TextStyle(color: FFitTheme.textPrimary),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Port (usually 9100)',
                          labelStyle: TextStyle(color: FFitTheme.textSub),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: FFitTheme.netColor),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Port is required';
                          }
                          final port = int.tryParse(v.trim());
                          if (port == null || port <= 0 || port > 65535) {
                            return 'Enter a valid port (1-65535)';
                          }
                          return null;
                        },
                      ),
                      if (loading) ...[
                        const SizedBox(height: 20),
                        const LinearProgressIndicator(color: FFitTheme.netColor),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel', style: TextStyle(color: FFitTheme.textSub)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FFitTheme.netColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: loading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setState(() => loading = true);

                          final name = nameController.text.trim();
                          final ip = ipController.text.trim();
                          final port = int.parse(portController.text.trim());
                          final subnet = subnetController.text.trim();

                          // Probe connection
                          try {
                            final socket = await Socket.connect(
                              ip,
                              port,
                              timeout: const Duration(seconds: 8),
                            );
                            socket.destroy();

                            // Probing success - connect and close dialog
                            final mockPrinter = DiscoveredPrinter(
                              type: ConnectionType.network,
                              name: name,
                              address: ip,
                              port: port,
                              subnetMask: subnet,
                            );

                            if (context.mounted) {
                              Navigator.pop(dialogContext);
                              _connect(mockPrinter, provider);
                            }
                          } catch (e, stack) {
                            debugPrint('❌ Probe connection failed to $ip:$port : $e');
                            debugPrint('$stack');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('❌ Connection failed: $e'),
                                  backgroundColor: FFitTheme.errorGlow,
                                ),
                              );
                            }
                          } finally {
                            if (context.mounted) {
                              setState(() => loading = false);
                            }
                          }
                        },
                  child: const Text('Connect'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBtTab(PrinterProvider provider) {
    return Column(
      children: [
        // BT scan button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: FFitTheme.btColor,
                foregroundColor: Colors.white,
              ),
              icon: provider.state == AppState.scanning
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.bluetooth_searching_rounded, size: 18),
              label: Text(provider.state == AppState.scanning
                  ? 'Scanning Bluetooth…'
                  : 'Scan Bluetooth (8s)'),
              onPressed: provider.state == AppState.scanning
                  ? null
                  : () => provider.scanBluetooth(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _buildList(provider.btPrinters, ConnectionType.bluetooth, provider),
        ),
      ],
    );
  }

  // ── Empty / loading states ────────────────────────────────────────────────
  Widget _buildScanning(String label) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: FFitTheme.accent),
        const SizedBox(height: 20),
        Text('Scanning $label…',
            style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 8),
        Text('Please wait',
            style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );

  Widget _buildEmpty(ConnectionType type) {
    final (icon, msg, hint) = switch (type) {
      ConnectionType.usb => (
        Icons.usb_off_rounded,
        'No USB printer found',
        'USB printer lagao aur Refresh karo'
      ),
      ConnectionType.network => (
        Icons.wifi_off_rounded,
        'No network printer found',
        'Printer same WiFi/LAN par hona chahiye'
      ),
      ConnectionType.bluetooth => (
        Icons.bluetooth_disabled_rounded,
        'No BT device found',
        '"Scan Bluetooth" button click karo'
      ),
    };

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: FFitTheme.surfaceAlt,
              shape: BoxShape.circle,
              border: Border.all(color: FFitTheme.border),
            ),
            child: Icon(icon, color: FFitTheme.textSub, size: 32),
          ),
          const SizedBox(height: 16),
          Text(msg,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(hint,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Refresh'),
            onPressed: () => _refresh(),
          ),
        ],
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  void _refresh() {
    if (_selectedTab == 2) {
      context.read<PrinterProvider>().scanBluetooth();
    } else {
      context.read<PrinterProvider>().scanAll();
    }
  }

  /// Show info dialog when user taps a non-printer device
  void _showNotPrinterDialog(DiscoveredPrinter device) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: FFitTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: FFitTheme.error.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.block_rounded,
                  color: FFitTheme.error, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Printer Nahi Hai'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${device.name}" ek printer nahi lag raha.\n\n'
              'Sirf USB Thermal Printers (USB Printing Class devices) '
              'ko select kar sakte hain.\n\n'
              'Agar ye aapka printer hai, to:\n'
              '• USB cable check karo\n'
              '• Printer ON hai?\n'
              '• Doosra USB port try karo',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _connect(
      DiscoveredPrinter printer, PrinterProvider provider) async {
    // Show confirm bottom sheet
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FFitTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ConnectSheet(printer: printer),
    );

    if (confirmed != true || !mounted) return;

    final config = printer.toConfig();
    final ok = await provider.connect(config);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? '✅ Connected to ${printer.name}'
              : '❌ ${provider.statusMessage}'),
          backgroundColor:
              ok ? FFitTheme.successGlow : FFitTheme.errorGlow,
        ),
      );
      if (ok) Navigator.pop(context);
    }
  }

  String _labelFor(ConnectionType t) {
    switch (t) {
      case ConnectionType.usb:       return 'USB';
      case ConnectionType.network:   return 'Network';
      case ConnectionType.bluetooth: return 'Bluetooth';
    }
  }
}

// ─── Connect bottom sheet ─────────────────────────────────────────────────────
class _ConnectSheet extends StatefulWidget {
  final DiscoveredPrinter printer;
  const _ConnectSheet({required this.printer});

  @override
  State<_ConnectSheet> createState() => _ConnectSheetState();
}

class _ConnectSheetState extends State<_ConnectSheet> {
  PaperWidth _paper = PaperWidth.mm58;

  @override
  Widget build(BuildContext context) {
    final p = widget.printer;
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: FFitTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Connect to Printer',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            // Printer info card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: cardBox(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(p.displayAddress,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, children: [
                    _chip(p.type.name.toUpperCase(), _typeColor(p.type)),
                    if (!p.likelyPrinter)
                      _chip('⚠️ May not be a printer', FFitTheme.warning),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // USB ke liye password warning
            if (p.type == ConnectionType.usb) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: FFitTheme.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: FFitTheme.warning.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_open_rounded,
                        color: FFitTheme.warning, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pehli baar connect karne par system password '
                        'dialog khulega — USB printer permission ke liye.',
                        style: TextStyle(
                          color: FFitTheme.warning,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            ElevatedButton.icon(
              icon: Icon(
                p.type == ConnectionType.usb
                    ? Icons.lock_open_rounded
                    : Icons.link_rounded,
                size: 18,
              ),
              label: Text(p.type == ConnectionType.usb
                  ? 'Connect (System Password)'
                  : 'Connect'),
              onPressed: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 8),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label,
        style: TextStyle(color: color, fontSize: 11,
            fontWeight: FontWeight.w600)),
  );

  Color _typeColor(ConnectionType t) {
    switch (t) {
      case ConnectionType.usb:       return FFitTheme.usbColor;
      case ConnectionType.network:   return FFitTheme.netColor;
      case ConnectionType.bluetooth: return FFitTheme.btColor;
    }
  }
}

class _PaperOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PaperOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: 200.ms,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? FFitTheme.accentGlow : FFitTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? FFitTheme.accent : FFitTheme.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                  color: selected ? FFitTheme.accent : FFitTheme.textSub,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                )),
          ),
        ),
      ),
    );
  }
}
