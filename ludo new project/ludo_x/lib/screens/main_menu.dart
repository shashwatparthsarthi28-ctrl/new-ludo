import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/progress.dart';
import '../core/theme.dart';
import '../services/models.dart';
import '../widgets/game_ui.dart';
import '../widgets/progress_widgets.dart';
import 'leaderboard_screen.dart';
import 'mode_select_screen.dart';
import 'online_lobby.dart';
import 'profile_screen.dart';
import 'rewards_screens.dart';
import 'shop_screen.dart';
import 'wallet_screen.dart';

/// Home menu (mirrors the mockup): profile strip + currencies, logo, four big
/// buttons, side shortcuts and a bottom menu row.
class MainMenu extends StatefulWidget {
  const MainMenu({super.key});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> with WidgetsBindingObserver {
  DailyStatus? _daily;
  Timer? _break;

  @override
  void initState() {
    super.initState();
    app.addListener(_r);
    _load();
    // Healthy-play reminder: a gentle nudge every 45 minutes.
    _break = Timer.periodic(const Duration(minutes: 45), (_) {
      if (mounted) toast(context, "You've been playing for a while. Take a short break!");
    });
  }

  @override
  void dispose() {
    _break?.cancel();
    app.removeListener(_r);
    super.dispose();
  }

  void _r() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    await app.refresh();
    try {
      final d = await app.backend.getDaily();
      if (mounted) setState(() => _daily = d);
    } catch (_) {}
  }

  Future<void> _go(Widget w) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    if (mounted) _load();
  }

  void _friends() {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Play With Friends'),
        content: const Text('Online rooms with friends are not part of this prototype (it has no real-time multiplayer server).\n\n'
            'You can still play with friends on this phone using Pass N Play - pass the device around, up to 4 players.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close', style: TextStyle(color: Gx.muted))),
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              _go(const ModeSelectScreen(kind: 'passnplay'));
            },
            child: const Text('Pass N Play', style: TextStyle(color: Gx.gold, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = app.profile;
    final level = Progress.levelOf(p?.xp ?? 0);
    final dot = _daily != null && !_daily!.claimedToday;
    return Scaffold(
      backgroundColor: Gx.bg,
      body: GameBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => _go(const ProfileScreen()),
                  child: Stack(alignment: Alignment.bottomCenter, children: [
                    AvatarView(index: p?.avatar ?? 0, size: 54),
                    Positioned(
                      bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(color: Gx.goldDark, borderRadius: BorderRadius.circular(9), border: Border.all(color: Colors.white, width: 1.5)),
                        child: Text('Lv $level', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p?.username ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(value: Progress.fraction(p?.xp ?? 0), minHeight: 8, backgroundColor: Colors.white24, color: Gx.goldLight),
                    ),
                  ]),
                ),
                const SizedBox(width: 10),
                const CurrencyBar(),
              ]),
            ),
            const Spacer(flex: 2),
            const FittedBox(child: Text('\u{1F451}', style: TextStyle(fontSize: 46))),
            const LogoText(size: 58),
            const SizedBox(height: 6),
            const MiniTag('SIMULATED MONEY - NO REAL PAYMENTS'),
            const Spacer(flex: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                SizedBox(
                  width: 66,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    SideButton(icon: Icons.card_giftcard, label: 'Daily\nRewards', dot: dot, onTap: () => _go(const DailyRewardsScreen())),
                    const SizedBox(height: 14),
                    SideButton(icon: Icons.military_tech, label: 'Achieve-\nments', onTap: () => _go(const AchievementsScreen())),
                  ]),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    GlossButton(label: 'Play Online', icon: Icons.public, colors: const [Color(0xFFFFD84A), Color(0xFFE88A00)], onTap: () => _go(const OnlineLobby())),
                    const SizedBox(height: 12),
                    GlossButton(label: 'Play With Friends', icon: Icons.groups, colors: const [Color(0xFF55E070), Color(0xFF138A2E)], onTap: _friends),
                    const SizedBox(height: 12),
                    GlossButton(label: 'Vs Computer', icon: Icons.smart_toy, colors: const [Color(0xFF59A6FF), Color(0xFF1250C8)], onTap: () => _go(const ModeSelectScreen(kind: 'computer'))),
                    const SizedBox(height: 12),
                    GlossButton(label: 'Pass N Play', icon: Icons.phone_android, colors: const [Color(0xFFC77BFF), Color(0xFF6A1FC2)], onTap: () => _go(const ModeSelectScreen(kind: 'passnplay'))),
                  ]),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 66,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    SideButton(icon: Icons.account_balance_wallet, label: 'Wallet', onTap: () => _go(const GameScaffold(title: 'Wallet', child: WalletScreen()))),
                    const SizedBox(height: 14),
                    SideButton(icon: Icons.storefront, label: 'Shop', onTap: () => _go(const ShopScreen())),
                  ]),
                ),
              ]),
            ),
            const Spacer(flex: 2),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(children: [
                Expanded(child: MenuTab(icon: Icons.person, label: 'Profile', onTap: () => _go(const ProfileScreen()))),
                const SizedBox(width: 8),
                Expanded(child: MenuTab(icon: Icons.bar_chart, label: 'Statistics', onTap: () => _go(const StatisticsScreen()))),
                const SizedBox(width: 8),
                Expanded(child: MenuTab(icon: Icons.leaderboard, label: 'Leaderboards', onTap: () => _go(const GameScaffold(title: 'Leaderboard', child: LeaderboardScreen())))),
                const SizedBox(width: 8),
                Expanded(child: MenuTab(icon: Icons.settings, label: 'Settings', onTap: () => _go(const SettingsScreen()))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
