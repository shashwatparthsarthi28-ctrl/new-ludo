import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../engine/bot_ai.dart';
import '../widgets/game_ui.dart';
import 'game_screen.dart';

/// "Select Game Mode" for Vs Computer and Pass N Play (free, no wallet changes).
class ModeSelectScreen extends StatefulWidget {
  final String kind; // 'computer' | 'passnplay'
  const ModeSelectScreen({super.key, required this.kind});

  @override
  State<ModeSelectScreen> createState() => _ModeSelectScreenState();
}

class _ModeSelectScreenState extends State<ModeSelectScreen> {
  int _players = 4;
  int _goal = 4; // 4 = classic, 2 = quick
  String _diff = 'medium';
  List<String> _names = ['Player 1', 'Player 2', 'Player 3', 'Player 4'];

  bool get _pnp => widget.kind == 'passnplay';

  Widget _tile(String label, IconData icon, bool on, VoidCallback f) => GestureDetector(
        onTap: f,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: on ? const [Color(0xFF3DDC84), Color(0xFF0E8F4A)] : const [Color(0xFF1B3FD0), Color(0xFF0C1E80)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: on ? Colors.white : Gx.gold, width: on ? 3 : 2),
            boxShadow: const [BoxShadow(color: Colors.black45, offset: Offset(0, 4))],
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Colors.white, size: 34),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 14)),
          ]),
        ),
      );

  Future<void> _editNames() async {
    final ctrls = [for (var i = 0; i < 4; i++) TextEditingController(text: _names[i])];
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Player names'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < _players; i++)
              TextField(controller: ctrls[i], maxLength: 12, decoration: InputDecoration(labelText: '${Gx.seatName[i]} seat')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel', style: TextStyle(color: Gx.muted))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save', style: TextStyle(color: Gx.gold, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _names = [for (var i = 0; i < 4; i++) ctrls[i].text.trim().isEmpty ? 'Player ${i + 1}' : ctrls[i].text.trim()]);
    }
  }

  void _cycleDiff() {
    const order = ['easy', 'medium', 'hard'];
    setState(() => _diff = order[(order.indexOf(_diff) + 1) % 3]);
  }

  void _play() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => GameScreen(
        mode: 'practice',
        entry: 0,
        difficulties: List.filled(3, _diff),
        players: _players,
        goal: _goal,
        hotSeat: _pnp,
        names: _pnp ? _names.take(_players).toList() : null,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'Select Game Mode',
      child: Column(children: [
        Expanded(
          child: GridView.count(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _tile('2 Players', Icons.people, _players == 2, () => setState(() => _players = 2)),
              _tile('3 Players', Icons.groups, _players == 3, () => setState(() => _players = 3)),
              _tile('4 Players', Icons.diversity_3, _players == 4, () => setState(() => _players = 4)),
              _tile('Quick Ludo\n2 tokens home', Icons.bolt, _goal == 2, () => setState(() => _goal = 2)),
              _tile('Classic Ludo\n4 tokens home', Icons.casino, _goal == 4, () => setState(() => _goal = 4)),
              _pnp
                  ? _tile('Player\nNames', Icons.edit, false, _editNames)
                  : _tile('Bots:\n${difficultyLabel(_diff)}', Icons.smart_toy, false, _cycleDiff),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            '${_pnp ? 'Pass the phone: each player rolls on their turn.' : 'You play Green against ${_players - 1} AI bot${_players == 2 ? '' : 's'}.'} '
            'Roll a 6 to leave the yard, capture to send tokens back, bring ${_goal == 2 ? '2' : 'all 4'} tokens home to finish.',
            textAlign: TextAlign.center,
            style: Gx.label(size: 12),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(40, 12, 40, 16),
          child: GlossButton(label: 'PLAY', icon: Icons.play_arrow_rounded, colors: const [Color(0xFFFFD84A), Color(0xFFE88A00)], onTap: _play, height: 62, showArrow: false),
        ),
      ]),
    );
  }
}
