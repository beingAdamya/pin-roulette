import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The card-table palette: green felt, chalk-white ink, coral and gold.
class Felt {
  static const green = Color(0xFF1F5A46);
  static const greenDark = Color(0xFF173F32);
  static const ink = Color(0xFFF3EFE2);
  static const text = Color(0xFF17231D);
  static const coral = Color(0xFFE0533D);
  static const gold = Color(0xFFD9A521);

  static const palettes = <List<Color>>[
    [
      Color(0xFF2A7A5F),
      Color(0xFFE0533D),
      Color(0xFFD9A521),
      Color(0xFF3E7CB1),
      Color(0xFF7A4E9C),
      Color(0xFF2F9C86),
    ],
    [Color(0xFFE0533D), Color(0xFFD9A521), Color(0xFF7A4E9C)],
    [Color(0xFF2A7A5F), Color(0xFFF3EFE2)],
  ];
}

const stageHint = TextStyle(color: Color(0xCCF3EFE2), fontSize: 13);
const stageStatus = TextStyle(
    color: Felt.ink, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: .5);

ThemeData buildTheme(Brightness brightness) {
  final light = brightness == Brightness.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: Felt.green,
    brightness: brightness,
    secondary: Felt.coral,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor:
        light ? const Color(0xFFEEF1EC) : const Color(0xFF0F1714),
  );
}

class GoButton extends StatelessWidget {
  const GoButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Felt.coral,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Felt.coral.withAlpha(110),
        disabledForegroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: .5),
      ),
      child: Text(label),
    );
  }
}

void tick(bool on) {
  if (on) HapticFeedback.selectionClick();
}

void thump(bool on) {
  if (on) HapticFeedback.heavyImpact();
}
