import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/shop_catalog.dart';
import '../core/sound.dart';
import '../core/theme.dart';
import '../screens/shop_screen.dart';
import '../screens/wallet_screen.dart';

/// Royal-blue game background with a faint scatter of dice.
class GameBackground extends StatelessWidget {
  final Widget child;
  const GameBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.35),
          radius: 1.25,
          colors: [Color(0xFF1B3FD0), Color(0xFF0A1A78), Color(0xFF050E45)],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(children: [
        const Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _DicePatternPainter()))),
        child,
      ]),
    );
  }
}

class _DicePatternPainter extends CustomPainter {
  const _DicePatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(5);
    final fill = Paint()..color = const Color(0x1A8FB4FF);
    final pip = Paint()..color = const Color(0x2A0A1A78);
    for (var i = 0; i < 16; i++) {
      final s = 34 + r.nextDouble() * 38;
      canvas.save();
      canvas.translate(r.nextDouble() * size.width, r.nextDouble() * size.height);
      canvas.rotate((r.nextDouble() - 0.5) * 1.2);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: s, height: s), Radius.circular(s * 0.2)), fill);
      final n = 1 + r.nextInt(6);
      final o = s * 0.25;
      final spots = <Offset>[
        if (n == 1 || n == 3 || n == 5) Offset.zero,
        if (n >= 2) Offset(-o, -o),
        if (n >= 2) Offset(o, o),
        if (n >= 4) Offset(o, -o),
        if (n >= 4) Offset(-o, o),
        if (n == 6) Offset(-o, 0),
        if (n == 6) Offset(o, 0),
      ];
      for (final p in spots) {
        canvas.drawCircle(p, s * 0.07, pip);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// "LUDO X": gold LUDO + red X with a dark outline.
class LogoText extends StatelessWidget {
  final double size;
  const LogoText({super.key, this.size = 28});

  Widget _word(String t, List<Color> colors) {
    final base = TextStyle(fontSize: size, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: size * 0.03, height: 1.0);
    return Stack(children: [
      Text(
        t,
        style: base.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = size * 0.16
            ..strokeJoin = StrokeJoin.round
            ..color = const Color(0xFF2A1400),
        ),
      ),
      ShaderMask(
        shaderCallback: (r) => LinearGradient(colors: colors, begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(r),
        child: Text(t, style: base.copyWith(color: Colors.white)),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
      _word('LUDO', const [Color(0xFFFFF1A8), Color(0xFFFFC21A), Color(0xFFE08A00)]),
      SizedBox(width: size * 0.12),
      _word('X', const [Color(0xFFFF7A7A), Color(0xFFE62222), Color(0xFF9E0B0B)]),
    ]);
  }
}

class RoundBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const RoundBackButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Sfx.play('tap');
        onTap();
      },
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [Color(0xFF3F7BFF), Color(0xFF1230B8)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const [BoxShadow(color: Colors.black45, offset: Offset(0, 3))],
        ),
        child: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 34),
      ),
    );
  }
}

/// Gold-bordered, cut-corner banner title.
class TitleBanner extends StatelessWidget {
  final String text;
  const TitleBanner(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 38, vertical: 10),
      decoration: ShapeDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF14339E), Color(0xFF0A1C70)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        shape: BeveledRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Gx.gold, width: 2.5)),
        shadows: const [BoxShadow(color: Colors.black45, offset: Offset(0, 4))],
      ),
      child: Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.4)),
    );
  }
}

/// Big glossy menu button (Play Online, Vs Computer, ...).
class GlossButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;
  final double height;
  final bool showArrow;
  const GlossButton({
    super.key,
    required this.label,
    required this.icon,
    required this.colors,
    required this.onTap,
    this.height = 60,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topCenter, end: Alignment.bottomCenter),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.9), width: 2),
        boxShadow: [
          BoxShadow(color: Color.lerp(colors.last, Colors.black, 0.45)!, offset: const Offset(0, 5)),
          BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 9)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: height * 0.46,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.white.withOpacity(0.38), Colors.white.withOpacity(0.02)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                ),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Sfx.play('tap');
                onTap();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(children: [
                  Icon(icon, color: Colors.white, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(label, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white, shadows: [Shadow(color: Colors.black38, offset: Offset(0, 2), blurRadius: 2)])),
                    ),
                  ),
                  if (showArrow) const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 32),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Round icon + label used on the home screen sides.
class SideButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool dot;
  const SideButton({super.key, required this.icon, required this.label, required this.onTap, this.dot = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Sfx.play('tap');
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFF2A4FD8), Color(0xFF0E2088)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              border: Border.all(color: Gx.gold, width: 2),
              boxShadow: const [BoxShadow(color: Colors.black45, offset: Offset(0, 4))],
            ),
            child: Icon(icon, color: Gx.goldLight, size: 30),
          ),
          if (dot)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(color: Gx.bad, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              ),
            ),
        ]),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1)),
      ]),
    );
  }
}

/// Bottom menu button (Profile, Statistics, ...).
class MenuTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const MenuTab({super.key, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Sfx.play('tap');
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF16309F), Color(0xFF0A1C70)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Gx.gold.withOpacity(0.85), width: 1.6),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Gx.goldLight, size: 22),
          const SizedBox(height: 3),
          FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white))),
        ]),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final Widget icon;
  final String text;
  final VoidCallback onPlus;
  const _Pill({required this.icon, required this.text, required this.onPlus});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF07135A).withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Gx.line, width: 1.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        icon,
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Colors.white)),
        const SizedBox(width: 5),
        GestureDetector(
          onTap: () {
            Sfx.play('tap');
            onPlus();
          },
          child: Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF4CE06A), Color(0xFF14962F)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 18),
          ),
        ),
      ]),
    );
  }
}

/// Coins (= demo wallet balance) and gems. "+" on coins opens the wallet,
/// "+" on gems explains how gems are earned.
class CurrencyBar extends StatelessWidget {
  const CurrencyBar({super.key});

  void _gemInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Earn gems'),
        content: const Text('Gems are an in-game currency and cannot be bought with money.\n\n'
            '- Reach a new level: +10 gems per level\n'
            '- Day 7 of the daily reward streak: +20 gems\n\n'
            'Spend them in the Shop on coin packs, dice skins and board themes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Got it', style: TextStyle(color: Gx.gold, fontWeight: FontWeight.w800))),
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShopScreen()));
            },
            child: const Text('Open shop', style: TextStyle(color: Gx.gold, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final p = app.profile;
        return Row(mainAxisSize: MainAxisSize.min, children: [
          _Pill(
            icon: const Icon(Icons.monetization_on, color: Color(0xFFFFC21A), size: 24),
            text: grouped(p?.balance ?? 0),
            onPlus: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GameScaffold(title: 'Wallet', child: WalletScreen()))),
          ),
          const SizedBox(width: 6),
          _Pill(
            icon: const Icon(Icons.diamond, color: Color(0xFF4FC3FF), size: 22),
            text: '${p?.gems ?? 0}',
            onPlus: () => _gemInfo(context),
          ),
        ]);
      },
    );
  }
}

/// Standard sub-screen frame: back button, logo, currencies, banner title.
class GameScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final bool currency;
  final VoidCallback? onBack;
  const GameScaffold({super.key, required this.title, required this.child, this.currency = true, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Gx.bg,
      body: GameBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(children: [
                RoundBackButton(onTap: onBack ?? () => Navigator.of(context).maybePop()),
                const SizedBox(width: 10),
                const Expanded(child: Align(alignment: Alignment.centerLeft, child: FittedBox(fit: BoxFit.scaleDown, child: LogoText(size: 24)))),
                if (currency) const CurrencyBar(),
              ]),
            ),
            Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: TitleBanner(title)),
            Expanded(child: child),
          ]),
        ),
      ),
    );
  }
}

/// Used for avatars of AI seats.
const List<int> kBotAvatars = [0, 7, 4, 8];

/// Handy accessor for the equipped dice skin.
DiceSkin currentDiceSkin() => diceSkinOf(app.profile?.diceSkin ?? 'classic');
BoardTheme currentBoardTheme() => boardThemeOf(app.profile?.boardTheme ?? 'classic');
