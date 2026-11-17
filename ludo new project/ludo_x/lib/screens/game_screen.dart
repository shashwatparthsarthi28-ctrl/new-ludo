import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/payout.dart';
import '../core/progress.dart';
import '../core/shop_catalog.dart';
import '../core/sound.dart';
import '../core/theme.dart';
import '../engine/bot_ai.dart';
import '../engine/fair_dice.dart';
import '../services/backend.dart';
import '../services/models.dart';
import '../widgets/board_widget.dart';
import '../widgets/dice_widget.dart';
import '../widgets/game_ui.dart';
import '../widgets/progress_widgets.dart';
import 'match_log_screen.dart';

String modeTitle(String mode) {
  switch (mode) {
    case 'practice':
      return 'Practice';
    case 'competitive':
      return 'Competitive Demo';
    default:
      return 'Pro Bot Challenge';
  }
}

/// Drives one match. It only ever sends intents to the backend and animates the
/// authoritative snapshots it gets back, so the client cannot influence dice,
/// balances or outcomes.
class GameController extends ChangeNotifier {
  final GameBackend backend;
  final String mode;
  final double entry;
  final List<String>? difficulties;
  final int players;
  final int goal;
  final bool hotSeat;
  final List<String>? names;

  GameController({
    required this.backend,
    required this.mode,
    this.entry = 0,
    this.difficulties,
    this.players = 4,
    this.goal = 4,
    this.hotSeat = false,
    this.names,
  });

  MatchSnapshot? snap;
  int startXp = 0;
  List<List<int>> display = List.generate(4, (_) => List<int>.filled(4, -1));
  int lastDice = 0;
  int lastRollSeat = 0;
  final Map<int, int> seatDice = {}; // last value rolled by each seat
  final Map<int, String> reactions = {}; // emoji / quick-chat bubbles
  final Map<int, Timer> _reactTimers = {};
  int faceShown = 0;
  bool rolling = false;
  bool busy = false;
  bool resumed = false;
  bool resultReady = false;
  String message = 'Setting up match...';
  String? fatal;
  int secondsLeft = 0;

  bool _disposed = false;
  bool _driving = false;
  bool _input = false;
  int _failures = 0;
  int _clockOffset = 0;
  int _timeoutCooldownUntil = 0;
  Timer? _ticker;
  final Random _rng = Random();

  bool get canRoll {
    final s = snap;
    return s != null && s.humanTurn && s.dice == null && !busy && !rolling && !_driving && !_input && !s.over;
  }

  Set<int> get movable {
    final s = snap;
    if (s == null || !s.humanTurn || s.dice == null || busy || rolling || _driving) return <int>{};
    return s.legal.toSet();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  String _turnMessage() {
    final s = snap;
    if (s == null) return '';
    if (s.over) return 'Match over';
    final name = s.seats[s.turn].displayName;
    if (!s.seats[s.turn].isBot) {
      return s.dice == null ? 'Your turn - tap the dice' : 'Choose a token to move';
    }
    return '$name is playing...';
  }

  void _adopt(MatchSnapshot s) {
    snap = s;
    display = s.tokens.map((r) => List<int>.from(r)).toList();
    _clockOffset = s.serverNowMs - DateTime.now().millisecondsSinceEpoch;
    message = _turnMessage();
  }

  Future<void> start() async {
    startXp = app.profile?.xp ?? 0;
    try {
      final s = await backend.createMatch(
        mode: mode,
        entry: entry,
        difficulties: difficulties,
        players: players,
        goal: goal,
        hotSeat: hotSeat,
        names: names,
      );
      resumed = s.resumed;
      _adopt(s);
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
      _notify();
      unawaited(app.refresh());
      unawaited(_drive());
    } catch (e) {
      fatal = e.toString();
      _notify();
    }
  }

  // ------------------------------------------------------------ animations
  Future<void> _animateRoll(MatchEvent ev, MatchSnapshot s) async {
    final name = s.seats[ev.seat].displayName;
    rolling = true;
    lastRollSeat = ev.seat;
    message = '$name rolls...';
    Sfx.play('dice');
    final end = DateTime.now().millisecondsSinceEpoch + 560;
    while (DateTime.now().millisecondsSinceEpoch < end && !_disposed) {
      faceShown = 1 + _rng.nextInt(6);
      _notify();
      await _wait(70);
    }
    rolling = false;
    faceShown = ev.value;
    lastDice = ev.value;
    seatDice[ev.seat] = ev.value;
    if (ev.value == 6) Sfx.play('six');
    if (ev.skipped != null) {
      message = ev.skipped == 'three_sixes' ? 'Three sixes in a row - turn forfeited' : '$name rolled ${ev.value} - no legal move';
      _notify();
      await _wait(950);
    } else {
      message = '$name rolled ${ev.value}';
      _notify();
      await _wait(320);
    }
  }

  Future<void> _animateMove(MatchEvent ev, MatchSnapshot s) async {
    final seat = ev.seat;
    final t = ev.token;
    final name = s.seats[seat].displayName;
    if (ev.from == -1) {
      display[seat][t] = 0;
      Sfx.play('move');
      _notify();
      await _wait(240);
    } else {
      for (var p = ev.from + 1; p <= ev.to && !_disposed; p++) {
        display[seat][t] = p;
        Sfx.play('move');
        _notify();
        await _wait(115);
      }
    }
    if (ev.captured.isNotEmpty) {
      Sfx.play('capture');
      Sfx.haptic(heavy: true);
      for (final c in ev.captured) {
        display[c[0]][c[1]] = -1;
      }
      message = '$name captured ${ev.captured.length == 1 ? 'a token' : '${ev.captured.length} tokens'}!';
      if (!s.hotSeat) {
        final moverBot = s.seats[seat].isBot;
        for (final c in ev.captured) {
          final victimBot = s.seats[c[0]].isBot;
          if (victimBot && !moverBot) {
            react(c[0], '\u{1F621}');
          } else if (!victimBot && moverBot) {
            react(seat, '\u{1F60E}');
          }
        }
      }
      _notify();
      await _wait(480);
    }
    if (ev.home) {
      Sfx.play('home');
      message = '$name brought a token home';
      _notify();
      await _wait(380);
    }
  }

  Future<void> _apply(MatchSnapshot next) async {
    final ev = next.event;
    if (ev != null && ev.type == 'roll') {
      await _animateRoll(ev, next);
    } else if (ev != null && ev.type == 'move') {
      await _animateMove(ev, next);
    }
    _adopt(next);
    _failures = 0;
    _notify();
  }

  // ------------------------------------------------------------ turn driver
  Future<void> _drive() async {
    if (_driving) return;
    _driving = true;
    _notify();
    try {
      while (!_disposed) {
        final s = snap;
        if (s == null || s.over) break;
        if (!s.seats[s.turn].isBot) {
          if (s.dice != null && s.legal.length == 1) {
            // only one possible move: play it automatically
            await _wait(420);
            if (_disposed || snap != s) continue;
            busy = true;
            _notify();
            final next = await backend.moveToken(s.id, s.legal.first, s.seq);
            await _apply(next);
            busy = false;
            continue;
          }
          break; // waiting for the human
        }
        await _wait(max(350, app.config.botThinkMs));
        if (_disposed || snap != s) continue;
        busy = true;
        _notify();
        final next = await backend.botStep(s.id, s.seq);
        await _apply(next);
        busy = false;
      }
    } catch (e) {
      busy = false;
      await _recover(e);
    } finally {
      _driving = false;
      _notify();
    }
    final cur = snap;
    if (cur != null && cur.over && !resultReady) {
      resultReady = true;
      _notify();
      unawaited(app.refresh());
    } else if (!_disposed && cur != null && !cur.over && fatal == null) {
      final botTurn = cur.seats[cur.turn].isBot;
      final autoMove = cur.humanTurn && cur.dice != null && cur.legal.length == 1;
      if (botTurn || autoMove) unawaited(_drive());
    }
  }

  Future<void> _recover(Object e) async {
    _failures++;
    final id = snap?.id;
    if (_failures > 3 || id == null) {
      fatal = e.toString();
      _notify();
      return;
    }
    message = 'Re-syncing with the server...';
    _notify();
    try {
      final fresh = await backend.getMatch(id);
      _adopt(fresh);
    } catch (e2) {
      fatal = e2.toString();
    }
    _notify();
  }

  // ------------------------------------------------------------ human input
  Future<void> onDiceTap() async {
    final s = snap;
    if (s == null || !canRoll) return;
    _input = true;
    busy = true;
    _notify();
    try {
      final next = await backend.rollDice(s.id, s.seq);
      await _apply(next);
    } catch (e) {
      await _recover(e);
    }
    busy = false;
    _input = false;
    _notify();
    unawaited(_drive());
  }

  Future<void> onTokenTap(int token) async {
    final s = snap;
    if (s == null || _input || !movable.contains(token)) return;
    _input = true;
    busy = true;
    _notify();
    try {
      final next = await backend.moveToken(s.id, token, s.seq);
      await _apply(next);
    } catch (e) {
      await _recover(e);
    }
    busy = false;
    _input = false;
    _notify();
    unawaited(_drive());
  }

  // ------------------------------------------------------------ turn timer
  void _tick() {
    final s = snap;
    if (s == null || s.over || _disposed) return;
    final nowSrv = DateTime.now().millisecondsSinceEpoch + _clockOffset;
    final leftMs = s.deadlineMs - nowSrv;
    final left = max(0, (leftMs / 1000).ceil());
    if (left != secondsLeft) {
      secondsLeft = left;
      if (s.humanTurn && left > 0 && left <= 5 && !busy) Sfx.play('tick');
      _notify();
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (s.humanTurn && leftMs <= -300 && !_input && !_driving && !busy && now > _timeoutCooldownUntil) {
      _timeout(s);
    }
  }

  Future<void> _timeout(MatchSnapshot s) async {
    _input = true;
    busy = true;
    message = "Time's up - auto play";
    _notify();
    try {
      final next = await backend.timeoutTurn(s.id, s.seq);
      await _apply(next);
    } catch (_) {
      _timeoutCooldownUntil = DateTime.now().millisecondsSinceEpoch + 1500;
      try {
        _adopt(await backend.getMatch(s.id));
      } catch (_) {}
    }
    busy = false;
    _input = false;
    _notify();
    unawaited(_drive());
  }

  Future<void> retry() async {
    final id = snap?.id;
    fatal = null;
    _failures = 0;
    if (id == null) {
      await start();
      return;
    }
    try {
      _adopt(await backend.getMatch(id));
    } catch (e) {
      fatal = e.toString();
    }
    _notify();
    unawaited(_drive());
  }

  Future<void> leave() async {
    final s = snap;
    if (s != null && !s.over) {
      try {
        await backend.abandonMatch(s.id);
      } catch (_) {}
    }
    unawaited(app.refresh());
  }

  void react(int seat, String text) {
    _reactTimers[seat]?.cancel();
    reactions[seat] = text;
    _notify();
    _reactTimers[seat] = Timer(const Duration(milliseconds: 2600), () {
      reactions.remove(seat);
      _notify();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    for (final t in _reactTimers.values) {
      t.cancel();
    }
    super.dispose();
  }
}

// =====================================================================================

class GameScreen extends StatefulWidget {
  final String mode;
  final double entry;
  final List<String>? difficulties;
  final int players;
  final int goal;
  final bool hotSeat;
  final List<String>? names;
  const GameScreen({
    super.key,
    required this.mode,
    this.entry = 0,
    this.difficulties,
    this.players = 4,
    this.goal = 4,
    this.hotSeat = false,
    this.names,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameController ctrl;
  bool _resultShown = false;
  bool _resumedToast = false;

  @override
  void initState() {
    super.initState();
    ctrl = GameController(
      backend: app.backend,
      mode: widget.mode,
      entry: widget.entry,
      difficulties: widget.difficulties,
      players: widget.players,
      goal: widget.goal,
      hotSeat: widget.hotSeat,
      names: widget.names,
    );
    ctrl.addListener(_onChange);
    ctrl.start();
  }

  void _onChange() {
    if (!mounted) return;
    if (ctrl.resumed && !_resumedToast && ctrl.snap != null) {
      _resumedToast = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) toast(context, 'Resumed your unfinished match - no second entry was charged.');
      });
    }
    if (ctrl.resultReady && !_resultShown) {
      _resultShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showResult();
      });
    }
  }

  @override
  void dispose() {
    ctrl.removeListener(_onChange);
    ctrl.dispose();
    super.dispose();
  }

  String get _title => widget.hotSeat ? 'Pass N Play' : (widget.mode == 'practice' ? 'Vs Computer' : modeTitle(widget.mode));

  Future<bool> _confirmLeave() async {
    final paid = widget.entry > 0;
    final r = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Leave match?'),
        content: Text(paid
            ? 'Leaving counts as a loss: your simulated entry is forfeited and you finish last with no reward.'
            : 'This match will end. Nothing is lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep playing')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Leave', style: TextStyle(color: Gx.bad))),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _showResult() async {
    final s = ctrl.snap!;
    if (s.hotSeat || s.humanRank == 1) Sfx.play('win');
    final gain = s.hotSeat ? 0 : Progress.xpForMatch(rank: s.humanRank, completed: s.status == 'completed');
    if (Progress.levelOf(ctrl.startXp + gain) > Progress.levelOf(ctrl.startXp)) {
      Future<void>.delayed(const Duration(milliseconds: 1100), () => Sfx.play('levelup'));
    }
    final again = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (c) => _ResultDialog(snap: s, startXp: ctrl.startXp),
    );
    if (!mounted) return;
    if (again == 'again') {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => GameScreen(
          mode: widget.mode,
          entry: widget.entry,
          difficulties: widget.difficulties,
          players: widget.players,
          goal: widget.goal,
          hotSeat: widget.hotSeat,
          names: widget.names,
        ),
      ));
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        final s = ctrl.snap;
        return PopScope(
          canPop: s == null || s.over || ctrl.fatal != null,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            if (await _confirmLeave()) {
              await ctrl.leave();
              if (mounted) Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            backgroundColor: Gx.bg,
            body: GameBackground(child: SafeArea(child: _body(s))),
          ),
        );
      },
    );
  }

  Widget _body(MatchSnapshot? s) {
    if (ctrl.fatal != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, color: Gx.bad, size: 56),
            const SizedBox(height: 16),
            Text(ctrl.fatal!, textAlign: TextAlign.center, style: const TextStyle(color: Gx.text)),
            const SizedBox(height: 22),
            GoldButton(label: 'Try again', icon: Icons.refresh, onPressed: ctrl.retry),
            const SizedBox(height: 10),
            GoldButton(label: 'Back', outlined: true, onPressed: () => Navigator.of(context).pop()),
          ]),
        ),
      );
    }
    if (s == null) return const Center(child: CircularProgressIndicator(color: Gx.gold));

    Widget slot(int seat, {required bool right, required bool bubbleBelow}) {
      if (s.seats[seat].inactive) return const Expanded(child: SizedBox());
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _PlayerCard(seat: seat, snap: s, ctrl: ctrl, rightSide: right, bubbleBelow: bubbleBelow),
        ),
      );
    }

    return Column(children: [
      _TopBar(
        title: _title,
        subtitle: s.entry > 0
            ? 'Demo entry ${inr(s.entry)}  |  Pool ${inr(s.entry * 4)}  |  1st ${inr(PayoutConfig(entry: s.entry, multipliers: s.multipliers).payouts[0])}'
            : '${s.activeSeats.length} players  |  ${s.state.goal == 2 ? 'Quick' : 'Classic'} Ludo${s.hotSeat ? '  |  pass the phone' : ''}',
        matchId: s.id,
        onClose: () async {
          if (s.over || await _confirmLeave()) {
            await ctrl.leave();
            if (mounted) Navigator.of(context).pop();
          }
        },
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          slot(0, right: false, bubbleBelow: true),
          slot(1, right: true, bubbleBelow: true),
        ]),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Center(
            child: BoardView(
              tokens: ctrl.display,
              movable: ctrl.movable,
              activeSeat: s.turn,
              tapSeat: s.humanTurn ? s.turn : 0,
              activeSeats: s.activeSeats.toSet(),
              theme: currentBoardTheme(),
              onTokenTap: ctrl.onTokenTap,
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          slot(3, right: false, bubbleBelow: false),
          slot(2, right: true, bubbleBelow: false),
        ]),
      ),
      _MessageBar(ctrl: ctrl, snap: s),
    ]);
  }
}

// ---------------------------------------------------------------- pieces

class _TopBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final String matchId;
  final VoidCallback onClose;
  const _TopBar({required this.title, required this.subtitle, required this.matchId, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
      child: Row(children: [
        IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26)),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title.toUpperCase(), style: Gx.display(14, color: Gx.goldLight)),
            const SizedBox(height: 2),
            Text(subtitle, style: Gx.label(size: 11), overflow: TextOverflow.ellipsis),
          ]),
        ),
        IconButton(
          tooltip: 'Match log',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchLogScreen(matchId: matchId))),
          icon: const Icon(Icons.receipt_long, color: Colors.white70, size: 22),
        ),
        AnimatedBuilder(
          animation: app,
          builder: (_, __) => IconButton(
            tooltip: 'Sound',
            onPressed: app.toggleSound,
            icon: Icon(app.soundOn ? Icons.volume_up : Icons.volume_off, color: Colors.white70, size: 22),
          ),
        ),
      ]),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final int seat;
  final MatchSnapshot snap;
  final GameController ctrl;
  final bool rightSide;
  final bool bubbleBelow;
  const _PlayerCard({required this.seat, required this.snap, required this.ctrl, required this.rightSide, required this.bubbleBelow});

  @override
  Widget build(BuildContext context) {
    final info = snap.seats[seat];
    final color = Gx.seat[seat];
    final active = !snap.over && snap.turn == seat;
    final home = snap.tokens[seat].where((p) => p == 56).length;
    final rankIdx = snap.state.ranking.indexOf(seat);
    final avatar = (seat == 0 && !snap.hotSeat) ? (app.profile?.avatar ?? 0) : kBotAvatars[seat];
    final total = max(1, snap.turnMs ~/ 1000);
    final frac = (ctrl.secondsLeft / total).clamp(0.0, 1.0);
    final urgent = active && snap.humanTurn && ctrl.secondsLeft <= 5;
    final rollingHere = ctrl.rolling && ctrl.lastRollSeat == seat;
    final diceVal = rollingHere ? ctrl.faceShown : (ctrl.seatDice[seat] ?? 0);
    final canTap = ctrl.canRoll && snap.turn == seat;

    final avatarWidget = Stack(alignment: Alignment.center, children: [
      if (active && snap.humanTurn)
        SizedBox(
          width: 54,
          height: 54,
          child: CircularProgressIndicator(value: frac, strokeWidth: 3.5, backgroundColor: Colors.white24, color: urgent ? Gx.bad : Gx.goldLight),
        ),
      Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 3)),
        child: AvatarView(index: avatar, size: 40, ring: false),
      ),
    ]);

    final diceWidget = DiceView(
      value: diceVal,
      rolling: rollingHere,
      enabled: canTap,
      color: color,
      size: 46,
      skin: currentDiceSkin(),
      onTap: ctrl.onDiceTap,
    );

    final tag = snap.hotSeat ? const MiniTag('PLAYER') : (info.isBot ? const MiniTag('AI BOT', color: Gx.muted) : const MiniTag('YOU'));
    final details = Expanded(
      child: Column(
        crossAxisAlignment: rightSide ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(info.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 3),
          Row(mainAxisSize: MainAxisSize.min, children: [
            tag,
            const SizedBox(width: 5),
            Text(rankIdx >= 0 ? ordinal(rankIdx + 1) : '$home/${snap.state.goal}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: rankIdx >= 0 ? Gx.gold : Colors.white70)),
          ]),
          if (info.isBot && info.difficulty != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('${difficultyLabel(info.difficulty!)} - ${personaLabel(info.persona ?? 'strategist')}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: Gx.muted, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );

    final row = rightSide
        ? [diceWidget, const SizedBox(width: 6), details, const SizedBox(width: 6), avatarWidget]
        : [avatarWidget, const SizedBox(width: 6), details, const SizedBox(width: 6), diceWidget];

    final bubble = ctrl.reactions[seat];
    return Stack(clipBehavior: Clip.none, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(7, 6, 7, 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF15329E), Color(0xFF0A1C70)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? Gx.goldLight : color, width: active ? 2.8 : 2),
          boxShadow: [
            const BoxShadow(color: Colors.black45, offset: Offset(0, 3)),
            if (active) BoxShadow(color: Gx.gold.withOpacity(0.55), blurRadius: 14),
          ],
        ),
        child: Row(children: row),
      ),
      if (bubble != null)
        Positioned(
          left: rightSide ? null : 10,
          right: rightSide ? 10 : null,
          top: bubbleBelow ? null : -34,
          bottom: bubbleBelow ? -34 : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)]),
            child: Text(bubble, style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w800, fontSize: bubble.runes.length <= 2 ? 22 : 13)),
          ),
        ),
    ]);
  }
}

class _MessageBar extends StatelessWidget {
  final GameController ctrl;
  final MatchSnapshot snap;
  const _MessageBar({required this.ctrl, required this.snap});

  Future<void> _pick(BuildContext context, bool emoji) async {
    final options = emoji
        ? ['\u{1F600}', '\u{1F602}', '\u{1F60E}', '\u{1F621}', '\u{1F62D}', '\u{1F44D}', '\u{1F44F}', '\u{1F525}']
        : ['Nice move!', 'Good luck!', 'Oops!', 'Well played!', 'Hurry up!', 'Roll a six!'];
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Gx.surface,
      builder: (c) => Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(spacing: 10, runSpacing: 10, children: [
          for (final o in options)
            GestureDetector(
              onTap: () => Navigator.pop(c, o),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: emoji ? 12 : 16, vertical: 10),
                decoration: BoxDecoration(color: Gx.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: Gx.line)),
                child: Text(o, style: TextStyle(fontSize: emoji ? 28 : 14, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
        ]),
      ),
    );
    if (choice != null) ctrl.react((snap.hotSeat && snap.humanTurn) ? snap.turn : 0, choice);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 2, 10, 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF07135A).withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Gx.line, width: 1.5),
      ),
      child: Row(children: [
        IconButton(
          tooltip: 'Quick chat',
          onPressed: () => _pick(context, false),
          icon: const Icon(Icons.chat_bubble_rounded, color: Gx.goldLight, size: 22),
        ),
        Expanded(
          child: Text(ctrl.message, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
        ),
        IconButton(
          tooltip: 'Emoji',
          onPressed: () => _pick(context, true),
          icon: const Icon(Icons.emoji_emotions_rounded, color: Gx.goldLight, size: 24),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- result

class _ResultDialog extends StatelessWidget {
  final MatchSnapshot snap;
  final int startXp;
  const _ResultDialog({required this.snap, required this.startXp});

  @override
  Widget build(BuildContext context) {
    final rank = snap.humanRank;
    final abandoned = snap.status == 'abandoned';
    final paid = snap.entry > 0;
    final table = PayoutConfig(entry: snap.entry, multipliers: snap.multipliers);
    final payout = abandoned ? 0.0 : (paid ? table.payoutForRank(rank) : 0.0);
    final net = payout - snap.entry;
    final fair = snap.revealedSeed != null && FairDice.verifyCommitment(snap.revealedSeed!, snap.commitment);
    final winnerName = snap.finalOrder.isEmpty ? '' : snap.seats[snap.finalOrder.first].name;
    final headline = abandoned
        ? 'MATCH ABANDONED'
        : (snap.hotSeat ? '${winnerName.toUpperCase()} WINS!' : (rank == 1 ? 'VICTORY!' : '${ordinal(rank).toUpperCase()} PLACE'));
    final celebrate = !abandoned && (snap.hotSeat || rank == 1);
    final gain = snap.hotSeat ? 0 : Progress.xpForMatch(rank: rank, completed: !abandoned && snap.status == 'completed');
    final levelUp = Progress.levelOf(startXp + gain) > Progress.levelOf(startXp);

    return Dialog(
      child: Stack(children: [
        if (celebrate) const Positioned.fill(child: IgnorePointer(child: ConfettiBurst())),
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(celebrate ? Icons.emoji_events : Icons.flag, size: 54, color: Gx.gold),
            const SizedBox(height: 8),
            Text(headline, textAlign: TextAlign.center, style: Gx.display(22, color: Gx.gold)),
            const SizedBox(height: 14),
            for (var i = 0; i < snap.finalOrder.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: (!snap.hotSeat && snap.finalOrder[i] == 0) ? Gx.gold.withOpacity(0.14) : Gx.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: (!snap.hotSeat && snap.finalOrder[i] == 0) ? Gx.gold : Gx.line),
                ),
                child: Row(children: [
                  SizedBox(width: 34, child: Text(ordinal(i + 1), style: const TextStyle(fontWeight: FontWeight.w900, color: Gx.gold))),
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: Gx.seat[snap.finalOrder[i]], shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(snap.seats[snap.finalOrder[i]].displayName, style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                  if (!snap.hotSeat) (snap.seats[snap.finalOrder[i]].isBot ? const MiniTag('AI', color: Gx.muted) : const MiniTag('YOU')),
                  if (paid) ...[
                    const SizedBox(width: 10),
                    Text(inr(table.payouts[i]), style: const TextStyle(color: Gx.goldLight, fontWeight: FontWeight.w800)),
                  ],
                ]),
              ),
            const SizedBox(height: 10),
            if (gain > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: Gx.gold.withOpacity(0.14), borderRadius: BorderRadius.circular(14), border: Border.all(color: Gx.gold)),
                child: Row(children: [
                  const Icon(Icons.bolt, color: Gx.gold),
                  const SizedBox(width: 8),
                  Text('+$gain XP', style: const TextStyle(fontWeight: FontWeight.w900, color: Gx.goldLight)),
                  const Spacer(),
                  if (levelUp) Text('LEVEL UP! +${kGemsPerLevel * (Progress.levelOf(startXp + gain) - Progress.levelOf(startXp))} gems', style: const TextStyle(fontWeight: FontWeight.w900, color: Gx.good, fontSize: 12)),
                ]),
              ),
            if (paid)
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  _row('Demo entry', inr(-snap.entry), Gx.bad),
                  _row('Simulated reward', inr(payout, sign: true), payout > 0 ? Gx.good : Gx.muted),
                  const Divider(height: 18),
                  _row('Net result', inr(net, sign: true), net >= 0 ? Gx.good : Gx.bad, bold: true),
                ]),
              )
            else
              Text(snap.hotSeat ? 'Pass N Play: no XP or wallet changes.' : 'Free match - no wallet changes.', style: const TextStyle(color: Gx.muted)),
            const SizedBox(height: 10),
            Row(children: [
              Icon(fair ? Icons.verified : Icons.help_outline, size: 16, color: fair ? Gx.good : Gx.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  fair ? 'Dice verified: revealed seed matches the commitment published before the match.' : 'Fairness data unavailable.',
                  style: Gx.label(size: 11, color: fair ? Gx.good : Gx.muted),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            GoldButton(label: 'Play again', icon: Icons.replay, onPressed: () => Navigator.pop(context, 'again')),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: GoldButton(
                  label: 'Match log',
                  outlined: true,
                  compact: true,
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchLogScreen(matchId: snap.id))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: GoldButton(label: 'Home', outlined: true, compact: true, onPressed: () => Navigator.pop(context, 'home'))),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _row(String l, String v, Color c, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(l, style: TextStyle(color: Gx.muted, fontWeight: bold ? FontWeight.w800 : FontWeight.w500))),
          Text(v, style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: bold ? 17 : 14)),
        ]),
      );
}
