import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/theme.dart';
import '../widgets/game_ui.dart';
import 'mode_screens.dart';

/// "Play Online" = the two demo-entry modes. There is no live matchmaking in this
/// prototype, so every opponent is a clearly labelled AI bot.
class OnlineLobby extends StatelessWidget {
  const OnlineLobby({super.key});

  @override
  Widget build(BuildContext context) {
    final cfg = app.config;
    return GameScaffold(
      title: 'Select Game Mode',
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        GlossButton(
          label: 'Competitive Demo - ${inr(cfg.competitiveEntry)}',
          icon: Icons.emoji_events,
          height: 72,
          colors: const [Color(0xFFFFD84A), Color(0xFFE88A00)],
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CompetitiveScreen())),
        ),
        const SizedBox(height: 14),
        GlossButton(
          label: 'Pro Bot Challenge',
          icon: Icons.military_tech,
          height: 72,
          colors: const [Color(0xFFFF7A5A), Color(0xFFC2260F)],
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProBotScreen())),
        ),
        const SizedBox(height: 18),
        const AppCard(
          child: Text(
            'Seats at the table are filled by AI bots, each clearly tagged AI BOT with its difficulty and strategy - there is no live matchmaking in this prototype. '
            'Entry fees and rewards are simulated demo coins only.',
            style: TextStyle(color: Gx.muted, height: 1.4, fontSize: 13),
          ),
        ),
      ]),
    );
  }
}
