import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/shop_catalog.dart';
import '../core/sound.dart';
import '../core/theme.dart';
import '../services/backend.dart';
import '../widgets/board_widget.dart';
import '../widgets/dice_widget.dart';
import '../widgets/game_ui.dart';

/// Shop: coin packs, dice skins and board themes. Everything is paid for with
/// GEMS, which are earned in-game (levels, daily streak) and can never be bought
/// with money. Coins are simulated demo coins.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int _tab = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    app.addListener(_r);
    app.refresh();
  }

  @override
  void dispose() {
    app.removeListener(_r);
    super.dispose();
  }

  void _r() {
    if (mounted) setState(() {});
  }

  Future<void> _do(Future<void> Function() f, String ok, {String? sound}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await f();
      if (sound != null) Sfx.play(sound);
      await app.refresh();
      if (mounted) toast(context, ok);
    } on BackendException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _owns(String kind, String id) => shopPrice(kind, id) == 0 || (app.profile?.owned.contains('$kind:$id') ?? false);

  Widget _tabButton(int i, String t) => Expanded(
        child: GestureDetector(
          onTap: () {
            Sfx.play('tap');
            setState(() => _tab = i);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              gradient: _tab == i ? Gx.goldGradient : null,
              color: _tab == i ? null : const Color(0xFF07135A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _tab == i ? Gx.goldLight : Gx.line, width: 1.6),
            ),
            child: Center(child: Text(t, style: TextStyle(fontWeight: FontWeight.w900, color: _tab == i ? Colors.black : Colors.white))),
          ),
        ),
      );

  Widget _gemPrice(int n) => Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.diamond, color: Color(0xFF4FC3FF), size: 16),
        const SizedBox(width: 3),
        Text('$n', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
      ]);

  Widget _action(String kind, String id, int price) {
    final p = app.profile;
    final owned = _owns(kind, id);
    final equipped = kind == 'dice' ? p?.diceSkin == id : p?.boardTheme == id;
    if (equipped) return const MiniTag('EQUIPPED', color: Gx.good);
    if (owned) {
      return GoldButton(
        label: 'EQUIP',
        compact: true,
        onPressed: _busy ? null : () => _do(() => app.backend.equipItem(kind, id), 'Equipped'),
      );
    }
    final afford = (p?.gems ?? 0) >= price;
    return GoldButton(
      label: afford ? 'BUY  $price gems' : 'NEED $price gems',
      compact: true,
      onPressed: (_busy || !afford) ? null : () => _do(() => app.backend.buyItem(kind, id), 'Purchased!', sound: 'coin'),
    );
  }

  Widget _coins() => ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        for (final c in kCoinPacks)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: Row(children: [
                const Icon(Icons.monetization_on, color: Color(0xFFFFC21A), size: 38),
                const SizedBox(width: 12),
                Expanded(child: Text('${grouped(c.coins.toDouble())} demo coins', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                GoldButton(
                  label: '${c.gems} gems',
                  compact: true,
                  onPressed: _busy || (app.profile?.gems ?? 0) < c.gems ? null : () => _do(() => app.backend.buyCoinPack(c.id), '+${c.coins} demo coins', sound: 'coin'),
                ),
              ]),
            ),
          ),
        Text('Coins are simulated and cannot be withdrawn. Gems are earned by levelling up and the day-7 daily reward - they cannot be bought with real money.',
            style: Gx.label(size: 11.5)),
      ]);

  Widget _dice() => GridView.count(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.82,
        children: [
          for (final s in kDiceSkins)
            AppCard(
              child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(s.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                DiceView(value: 5, rolling: false, enabled: false, color: Gx.gold, size: 62, skin: s),
                s.price == 0 ? const MiniTag('FREE') : _gemPrice(s.price),
                _action('dice', s.id, s.price),
              ]),
            ),
        ],
      );

  Widget _themes() => GridView.count(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.82,
        children: [
          for (final t in kBoardThemes)
            AppCard(
              child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(t.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                SizedBox(width: 80, height: 80, child: CustomPaint(painter: BoardPainter(theme: t))),
                t.price == 0 ? const MiniTag('FREE') : _gemPrice(t.price),
                _action('theme', t.id, t.price),
              ]),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'Shop',
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Row(children: [_tabButton(0, 'Coins'), _tabButton(1, 'Dices'), _tabButton(2, 'Themes')]),
        ),
        Expanded(child: _tab == 0 ? _coins() : (_tab == 1 ? _dice() : _themes())),
      ]),
    );
  }
}
