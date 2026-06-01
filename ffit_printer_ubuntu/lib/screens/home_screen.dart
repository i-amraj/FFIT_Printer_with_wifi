import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../services/printer_provider.dart';
import '../theme/app_theme.dart';
import '../models/printer_config.dart';
import 'discovery_screen.dart';
import 'settings_screen.dart';
import '../widgets/status_badge.dart';
import '../widgets/action_button.dart';
import '../widgets/step_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PrinterProvider>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: FFitTheme.bgGradient),
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    _buildStatusCard(),
                    const SizedBox(height: 20),
                    _buildActionRow(),
                    const SizedBox(height: 28),
                    _buildStepsSection(),
                    const SizedBox(height: 28),
                    _buildCupsSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 40, 16, 20),
      child: Row(
        children: [
          // Logo + title
          Container(
            width: 40, height: 40,
            decoration: glowBox(color: FFitTheme.accent, radius: 12),
            child: const Icon(Icons.print_rounded,
                color: FFitTheme.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('FFit Printer',
                  style: Theme.of(context).textTheme.titleLarge),
              Text('Ubuntu Thermal Driver',
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: FFitTheme.textSub),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0);
  }

  // ── Status card ────────────────────────────────────────────────────────────
  Widget _buildStatusCard() {
    return Consumer<PrinterProvider>(
      builder: (_, provider, __) {
        final connected = provider.isConnected;
        final config    = provider.savedConfig;
        final isLoading = provider.state == AppState.connecting;

        final glowColor  = connected ? FFitTheme.success : FFitTheme.error;
        final statusText = connected
            ? (config?.name ?? 'Printer Connected')
            : 'No Printer Connected';

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: glowBox(color: glowColor),
          child: Row(
            children: [
              // Animated status dot
              StatusBadge(connected: connected, loading: isLoading),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(statusText,
                        style: Theme.of(context).textTheme.titleMedium),
                    if (config != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _chip(config.typeLabel,
                              _typeColor(config.type)),
                          const SizedBox(width: 8),
                          Text(config.displayAddress,
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ],
                    if (provider.statusMessage.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(provider.statusMessage,
                          style: TextStyle(
                            color: provider.hasError
                                ? FFitTheme.error
                                : FFitTheme.textSub,
                            fontSize: 12,
                          )),
                    ],
                  ],
                ),
              ),
              if (connected)
                IconButton(
                  icon: const Icon(Icons.link_off_rounded,
                      color: FFitTheme.textSub, size: 20),
                  onPressed: () => provider.disconnect(),
                  tooltip: 'Disconnect',
                ),
            ],
          ),
        ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0);
      },
    );
  }

  // ── Action buttons row ────────────────────────────────────────────────────
  Widget _buildActionRow() {
    return Consumer<PrinterProvider>(
      builder: (_, provider, __) {
        final busy = provider.state == AppState.scanning ||
            provider.state == AppState.connecting ||
            provider.state == AppState.printing;

        return Row(
          children: [
            Expanded(
              child: ActionButton(
                label: 'Find Printer',
                icon: Icons.search_rounded,
                gradient: FFitTheme.accentGradient,
                loading: provider.state == AppState.scanning,
                onPressed: busy
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const DiscoveryScreen()),
                        ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ActionButton(
                label: 'Test Print',
                icon: Icons.receipt_long_rounded,
                color: FFitTheme.success,
                loading: provider.state == AppState.printing,
                onPressed: (busy || !provider.isConnected)
                    ? null
                    : () async {
                        final ok = await provider.testPrint();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(provider.statusMessage)),
                          );
                        }
                      },
              ),
            ),
          ],
        ).animate().fadeIn(delay: 200.ms);
      },
    );
  }

  // ── Steps section ─────────────────────────────────────────────────────────
  Widget _buildStepsSection() {
    final steps = [
      ('1', Icons.bluetooth_searching_rounded,
          'Printer pair karo (USB lagao ya BT pair karo ya IP note karo)'),
      ('2', Icons.wifi_find_rounded,
          '"Find Printer" click karo → USB / Network / Bluetooth tab select karo'),
      ('3', Icons.link_rounded,
          'Printer select karo → Connect → Test Print se check karo'),
      ('4', Icons.print_rounded,
          'Chrome ya kisi bhi app mein Print → "FFit Thermal" select karo → Done!'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Setup Guide', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 14),
        ...steps.asMap().entries.map((e) =>
            StepCard(
              num:   e.value.$1,
              icon:  e.value.$2,
              text:  e.value.$3,
              delay: (e.key * 60).ms,
            )),
      ],
    );
  }

  // ── CUPS section ──────────────────────────────────────────────────────────
  Widget _buildCupsSection() {
    return Consumer<PrinterProvider>(
      builder: (_, provider, __) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: cardBox(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.settings_applications_rounded,
                      color: FFitTheme.accent, size: 20),
                  const SizedBox(width: 10),
                  Text('CUPS System Integration',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'CUPS mein register karne ke baad Chrome, LibreOffice, '
                'aur system ki har app mein "FFit Thermal" printer dikhega.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                  label: const Text('Register with CUPS'),
                  onPressed: provider.isConnected
                      ? () async {
                          final ok = await provider.registerWithCups();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(provider.statusMessage)),
                            );
                          }
                        }
                      : null,
                ),
              ),
              if (!provider.isConnected) ...[
                const SizedBox(height: 8),
                Text('⚠️ Pehle printer connect karo',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: FFitTheme.warning, fontSize: 12)),
              ],
            ],
          ),
        ).animate().fadeIn(delay: 400.ms);
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color:        color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
  );

  Color _typeColor(ConnectionType t) {
    switch (t) {
      case ConnectionType.usb:       return FFitTheme.usbColor;
      case ConnectionType.network:   return FFitTheme.netColor;
      case ConnectionType.bluetooth: return FFitTheme.btColor;
    }
  }
}
