import 'package:flutter/material.dart';

import 'sound.dart';

/// LUDO X design tokens: black surfaces, gold accents.
class Gx {
  static const Color bg = Color(0xFF081664);
  static const Color surface = Color(0xFF0E2088);
  static const Color card = Color(0xFF132A92);
  static const Color cardHi = Color(0xFF1D3CBA);
  static const Color line = Color(0xFF4A74F0);
  static const Color gold = Color(0xFFFFC21A);
  static const Color goldLight = Color(0xFFFFE066);
  static const Color goldDark = Color(0xFFFF9500);
  static const Color text = Color(0xFFFFFFFF);
  static const Color muted = Color(0xFFA9BEF5);
  static const Color good = Color(0xFF3DDC84);
  static const Color bad = Color(0xFFFF5470);

  // Seat colours, clockwise from top-left.
  static const List<Color> seat = [Color(0xFF2FC24F), Color(0xFFFFD21F), Color(0xFF2B8CFF), Color(0xFFF0383B)];
  static const List<String> seatName = ['Green', 'Yellow', 'Blue', 'Red'];

  static const LinearGradient goldGradient = LinearGradient(
    colors: [goldLight, gold, goldDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static TextStyle display(double size, {Color color = text}) =>
      TextStyle(fontSize: size, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: color, height: 1.1);

  static TextStyle label({Color color = muted, double size = 12}) =>
      TextStyle(fontSize: size, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: color);

  static ThemeData theme() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        onPrimary: Colors.black,
        secondary: goldLight,
        surface: surface,
        onSurface: text,
        error: bad,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: false,
        foregroundColor: text,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: text),
      ),
      cardTheme: CardThemeData(color: card, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: line)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        labelStyle: const TextStyle(color: muted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: gold, width: 1.5)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: gold.withOpacity(0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: s.contains(WidgetState.selected) ? gold : muted,
            )),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? gold : muted)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cardHi,
        contentTextStyle: const TextStyle(color: text, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerColor: line,
    );
  }
}

// ---------------------------------------------------------------- formatting

String _group(String digits) {
  final sb = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) sb.write(',');
    sb.write(digits[i]);
  }
  return sb.toString();
}

/// Formats a demo amount, e.g. 1234.5 -> "₹1,234.50", 160 -> "₹160".
String inr(double v, {bool sign = false}) {
  final neg = v < 0;
  final a = v.abs();
  final whole = (a - a.roundToDouble()).abs() < 0.005;
  final s = whole ? a.round().toString() : a.toStringAsFixed(2);
  final parts = s.split('.');
  final out = '₹${_group(parts[0])}${parts.length > 1 ? '.${parts[1]}' : ''}';
  if (neg) return '-$out';
  return sign && v > 0 ? '+$out' : out;
}

/// 25760 -> "25,760" (coin counters).
String grouped(double v) => _group(v.round().abs().toString());

String pct(double v) => '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)}%';

String ordinal(int n) {
  switch (n) {
    case 1:
      return '1st';
    case 2:
      return '2nd';
    case 3:
      return '3rd';
    default:
      return '${n}th';
  }
}

String timeAgo(int ms) {
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  final t = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${t.day}/${t.month}/${t.year}';
}

void toast(BuildContext context, String msg, {bool error = false}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Row(children: [
      Icon(error ? Icons.error_outline : Icons.check_circle_outline, color: error ? Gx.bad : Gx.gold, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(msg)),
    ]),
  ));
}

// ---------------------------------------------------------------- shared widgets

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool glow;
  final Color? borderColor;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.glow = false, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Gx.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor ?? (glow ? Gx.gold.withOpacity(0.55) : Gx.line)),
        boxShadow: glow ? [BoxShadow(color: Gx.gold.withOpacity(0.16), blurRadius: 22, spreadRadius: 1)] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class GoldButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool outlined;
  final bool loading;
  final bool compact;
  const GoldButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.outlined = false,
    this.loading = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final fg = outlined ? Gx.gold : Colors.black;
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
        else if (icon != null)
          Icon(icon, size: compact ? 18 : 20, color: fg),
        if (loading || icon != null) const SizedBox(width: 8),
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8, fontSize: compact ? 13 : 15, color: fg)),
        ),
      ],
    );
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Container(
        height: compact ? 42 : 52,
        decoration: BoxDecoration(
          gradient: outlined ? null : Gx.goldGradient,
          borderRadius: BorderRadius.circular(compact ? 12 : 16),
          border: outlined ? Border.all(color: Gx.gold, width: 1.4) : null,
          boxShadow: outlined || !enabled ? null : [const BoxShadow(color: Color(0xFFB36B00), offset: Offset(0, 4)), BoxShadow(color: Gx.gold.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(compact ? 12 : 16),
            onTap: enabled
                ? () {
                    Sfx.play('tap');
                    onPressed!();
                  }
                : null,
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Center(child: child)),
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(gradient: Gx.goldGradient, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Expanded(child: Text(title.toUpperCase(), style: Gx.display(14))),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!, style: const TextStyle(color: Gx.gold, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
      ]),
    );
  }
}

const List<IconData> _avatarIcons = [
  Icons.sports_esports, Icons.rocket_launch, Icons.local_fire_department, Icons.bolt,
  Icons.diamond, Icons.shield, Icons.star, Icons.pets,
  Icons.psychology, Icons.sports_martial_arts, Icons.emoji_events, Icons.casino,
];
const List<List<Color>> _avatarColors = [
  [Color(0xFFF6D77A), Color(0xFF8C6D1F)], [Color(0xFFFF8A65), Color(0xFFB71C1C)], [Color(0xFFFFB74D), Color(0xFFE65100)],
  [Color(0xFFFFF176), Color(0xFFF9A825)], [Color(0xFF80DEEA), Color(0xFF00838F)], [Color(0xFF90CAF9), Color(0xFF1565C0)],
  [Color(0xFFCE93D8), Color(0xFF6A1B9A)], [Color(0xFFA5D6A7), Color(0xFF2E7D32)], [Color(0xFFF48FB1), Color(0xFFAD1457)],
  [Color(0xFFBCAAA4), Color(0xFF4E342E)], [Color(0xFFFFE082), Color(0xFFFF8F00)], [Color(0xFFB0BEC5), Color(0xFF37474F)],
];
const int kAvatarCount = 12;

class AvatarView extends StatelessWidget {
  final int index;
  final double size;
  final bool ring;
  const AvatarView({super.key, required this.index, this.size = 48, this.ring = true});

  @override
  Widget build(BuildContext context) {
    final i = index.clamp(0, kAvatarCount - 1);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: _avatarColors[i], begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: ring ? Border.all(color: Gx.gold, width: size > 60 ? 3 : 2) : null,
      ),
      child: Icon(_avatarIcons[i], color: Colors.black87, size: size * 0.5),
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  const StatTile({super.key, required this.label, required this.value, this.icon, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          if (icon != null) ...[Icon(icon, size: 15, color: Gx.gold), const SizedBox(width: 6)],
          Expanded(child: Text(label.toUpperCase(), style: Gx.label(size: 10.5), overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: Gx.display(22, color: valueColor ?? Gx.text)),
        ),
      ]),
    );
  }
}

/// Always-visible reminder that no real money is involved.
class SimBanner extends StatelessWidget {
  final bool compact;
  const SimBanner({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 6 : 10),
      decoration: BoxDecoration(
        color: Gx.gold.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Gx.gold.withOpacity(0.35)),
      ),
      child: Row(children: [
        const Icon(Icons.science_outlined, size: 16, color: Gx.gold),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            compact
                ? 'SIMULATED MONEY - no real payments'
                : 'Simulated-money prototype. No real money is deposited, withdrawn or won. Real payments are disabled.',
            style: const TextStyle(fontSize: 11.5, color: Gx.goldLight, fontWeight: FontWeight.w600, height: 1.3),
          ),
        ),
      ]),
    );
  }
}

class MiniTag extends StatelessWidget {
  final String text;
  final Color color;
  const MiniTag(this.text, {super.key, this.color = Gx.gold});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(text, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: color)),
    );
  }
}
