import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/printer_provider.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => PrinterProvider(),
      child: const FFitPrinterApp(),
    ),
  );
}

class FFitPrinterApp extends StatelessWidget {
  const FFitPrinterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FFit Printer — Ubuntu',
      debugShowCheckedModeBanner: false,
      theme: FFitTheme.theme,
      home: const HomeScreen(),
    );
  }
}
