import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

/// Step card for the setup guide on the home screen
class StepCard extends StatelessWidget {
  final String num;
  final IconData icon;
  final String text;
  final Duration delay;

  const StepCard({
    super.key,
    required this.num,
    required this.icon,
    required this.text,
    this.delay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: cardBox(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step number circle
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: FFitTheme.accentGradient,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(num,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    )),
              ),
            ),
            const SizedBox(width: 14),
            // Icon + text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: FFitTheme.accent, size: 18),
                  const SizedBox(height: 6),
                  Text(text,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: delay).fadeIn().slideX(begin: 0.05, end: 0);
  }
}
