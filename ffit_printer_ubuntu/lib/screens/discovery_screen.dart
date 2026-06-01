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
      context.read<PrinterProvider>().scanAll();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
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
            _buildList(provider.netPrinters, ConnectionType.network, provider),
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
          // Non-printer tap: show "not a printer" dialog from screen
          onNotPrinter: p.isSelectable ? null : () => _showNotPrinterDialog(p),
        ).animate().fadeIn(delay: (i * 50).ms).slideX(begin: 0.1, end: 0);
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
