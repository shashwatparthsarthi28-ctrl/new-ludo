import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/sound.dart';
import '../core/theme.dart';
import '../services/backend.dart';
import '../services/models.dart';
import '../widgets/game_ui.dart';
import '../widgets/progress_widgets.dart';

class DailyRewardsScreen extends StatefulWidget {
  const DailyRewardsScreen({super.key});

  @override
  State<DailyRewardsScreen> createState() => _DailyRewardsScreenState();
}

class _DailyRewardsScreenState extends State<DailyRewardsScreen> {
  DailyStatus? _d;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await app.backend.getDaily();
      if (mounted) setState(() => _d = d);
    } catch (_) {}
  }

  Future<void> _claim() async {
    try {
      final amt = await app.backend.claimDaily();
      Sfx.play('coin');
      await app.refresh();
      await _load();
      if (mounted) toast(context, 'Daily reward: +${inr(amt.toDouble())} demo coins (simulated)');
    } on BackendException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'Daily Rewards',
      child: ListView(padding: const EdgeInsets.all(16), children: [
        if (_d == null) const Center(child: CircularProgressIndicator(color: Gx.gold)) else DailyRewardCard(status: _d!, onClaim: _claim),
        const SizedBox(height: 12),
        Text('Come back every day to keep your streak. Day 7 also gives bonus gems. Rewards are simulated demo coins.', style: Gx.label(size: 12)),
      ]),
    );
  }
}

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = app.profile;
    return GameScaffold(
      title: 'Achievements',
      child: p == null ? const SizedBox() : ListView(padding: const EdgeInsets.all(16), children: [AchievementsGrid(profile: p)]),
    );
  }
}
