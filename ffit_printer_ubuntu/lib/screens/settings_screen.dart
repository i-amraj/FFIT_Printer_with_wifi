import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../services/printer_provider.dart';
import '../theme/app_theme.dart';
import '../models/printer_config.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: FFitTheme.bgGradient),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: FFitTheme.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Text('Settings',
                      style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ).animate().fadeIn().slideY(begin: -0.1),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildPrinterSection(context),
                    const SizedBox(height: 16),
                    _buildSystemSection(context),
                    const SizedBox(height: 16),
                    _buildAboutSection(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Printer info section ──────────────────────────────────────────────────
  Widget _buildPrinterSection(BuildContext context) {
    return Consumer<PrinterProvider>(
      builder: (_, p, __) {
        final config = p.savedConfig;
        return _Section(
          title: 'Current Printer',
          icon: Icons.print_rounded,
          child: config == null
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Koi printer configure nahi hai',
                      style: Theme.of(context).textTheme.bodyMedium),
                )
              : Column(
                  children: [
                    _InfoRow('Name',    config.name),
                    _InfoRow('Type',    config.typeLabel),
                    _InfoRow('Address', config.displayAddress),
                    _InfoRow('Paper',   '${config.paperWidthMm}mm'),
                    const SizedBox(height: 8),
                    // Config file path
                    FutureBuilder<String>(
                      future: p.configPath,
                      builder: (_, snap) {
                        final path = snap.data ?? '…';
                        return GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: path));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Path copied!')),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            decoration: BoxDecoration(
                              color: FFitTheme.surfaceAlt,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: FFitTheme.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.folder_open_rounded,
                                    color: FFitTheme.accent, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(path,
                                      style: const TextStyle(
                                        color: FFitTheme.textSub,
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                      )),
                                ),
                                const Icon(Icons.copy_rounded,
                                    color: FFitTheme.textSub, size: 14),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    // Clear button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                              foregroundColor: FFitTheme.error,
                              side: const BorderSide(color: FFitTheme.error)),
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 16),
                          label: const Text('Clear Printer Config'),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                backgroundColor: FFitTheme.surface,
                                title: const Text('Clear Config?'),
                                content: const Text(
                                    'Printer configuration delete ho jayega.'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Delete',
                                        style: TextStyle(
                                            color: FFitTheme.error)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await p.disconnect();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
        ).animate().fadeIn(delay: 100.ms);
      },
    );
  }

  // ── Paper size section ────────────────────────────────────────────────────
  Widget _buildPaperSection(BuildContext context) {
    return Consumer<PrinterProvider>(
      builder: (_, p, __) {
        final current = p.savedConfig?.paperWidth ?? PaperWidth.mm58;
        return _Section(
          title: 'Paper Size',
          icon: Icons.receipt_long_rounded,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _PaperToggle(
                    label: '58mm',
                    sub: '384px width',
                    selected: current == PaperWidth.mm58,
                    onTap: () => p.setPaperWidth(PaperWidth.mm58),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PaperToggle(
                    label: '80mm',
                    sub: '576px width',
                    selected: current == PaperWidth.mm80,
                    onTap: () => p.setPaperWidth(PaperWidth.mm80),
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: 200.ms);
      },
    );
  }

  // ── System section ────────────────────────────────────────────────────────
  Widget _buildSystemSection(BuildContext context) {
    return Consumer<PrinterProvider>(
      builder: (_, p, __) => _Section(
        title: 'System',
        icon: Icons.settings_rounded,
        child: Column(
          children: [
            _ActionTile(
              icon: Icons.add_circle_outline_rounded,
              label: 'Register with CUPS',
              sub: 'Chrome & apps mein printer dikhega',
              color: FFitTheme.accent,
              onTap: p.isConnected
                  ? () async {
                      final ok = await p.registerWithCups();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(p.statusMessage)),
                        );
                      }
                    }
                  : null,
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _ActionTile(
              icon: Icons.terminal_rounded,
              label: 'Permission Setup',
              sub: 'USB ke liye lp group mein add karo',
              color: FFitTheme.warning,
              onTap: () => _showPermissionGuide(context),
            ),
          ],
        ),
      ).animate().fadeIn(delay: 300.ms),
    );
  }

  // ── About section ─────────────────────────────────────────────────────────
  Widget _buildAboutSection(BuildContext context) {
    return _Section(
      title: 'About',
      icon: Icons.info_outline_rounded,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow('App',     'FFit Printer Driver'),
            _InfoRow('Version', '1.0.0'),
            _InfoRow('By',      'FFIT.IO'),
            _InfoRow('Support', 'USB · Network · Bluetooth'),
            _InfoRow('ESC/POS', '58mm thermal only'),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  void _showPermissionGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: FFitTheme.surface,
        title: const Text('USB Permission Setup'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'USB printer ko directly use karne ke liye '
                'apne user ko "lp" group mein add karo:',
                style: TextStyle(color: FFitTheme.textSub, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _CodeBlock('sudo usermod -aG lp \$USER'),
              const SizedBox(height: 8),
              const Text('Uske baad logout karke wapas login karo.',
                  style: TextStyle(color: FFitTheme.textSub, fontSize: 13)),
              const SizedBox(height: 16),
              const Text('Bluetooth ke liye:',
                  style: TextStyle(color: FFitTheme.textPrimary,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _CodeBlock('sudo usermod -aG bluetooth \$USER'),
              const SizedBox(height: 4),
              _CodeBlock('sudo systemctl enable bluetooth'),
              const SizedBox(height: 4),
              _CodeBlock('sudo systemctl start bluetooth'),
            ],
          ),
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
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: cardBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Icon(icon, color: FFitTheme.accent, size: 18),
                const SizedBox(width: 8),
                Text(title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: FFitTheme.accent)),
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(value,
                style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color color;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(label),
      subtitle: Text(sub),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: FFitTheme.textSub),
      onTap: onTap,
      enabled: onTap != null,
    );
  }
}

class _PaperToggle extends StatelessWidget {
  final String label, sub;
  final bool selected;
  final VoidCallback onTap;
  const _PaperToggle({
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color:        selected ? FFitTheme.accentGlow : FFitTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? FFitTheme.accent : FFitTheme.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                  color: selected ? FFitTheme.accent : FFitTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                )),
            const SizedBox(height: 2),
            Text(sub,
                style: TextStyle(
                  color: selected ? FFitTheme.accent.withOpacity(0.7)
                      : FFitTheme.textSub,
                  fontSize: 11,
                )),
          ],
        ),
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String code;
  const _CodeBlock(this.code);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Clipboard.setData(ClipboardData(text: code)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0C10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: FFitTheme.border),
        ),
        child: Text(code,
            style: const TextStyle(
              fontFamily: 'monospace',
              color: FFitTheme.success,
              fontSize: 12,
            )),
      ),
    );
  }
}
