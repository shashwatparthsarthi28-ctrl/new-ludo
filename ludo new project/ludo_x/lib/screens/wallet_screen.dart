import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/theme.dart';
import '../services/models.dart';
import '../widgets/dialogs.dart';

/// Simulated wallet: balance, demo deposit / withdrawal request and the full
/// ledger. The balance shown is whatever the backend returns.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  List<WalletTxn> _tx = [];
  bool _loading = true;
  String _filter = 'all';
  Timer? _t;

  @override
  void initState() {
    super.initState();
    app.addListener(_r);
    _load();
    // lets "Pending (simulated)" withdrawals flip to completed while the screen is open
    _t = Timer.periodic(const Duration(seconds: 5), (_) => _r());
  }

  @override
  void dispose() {
    _t?.cancel();
    app.removeListener(_r);
    super.dispose();
  }

  void _r() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    await app.refresh();
    try {
      final t = await app.backend.getTransactions();
      if (mounted) setState(() => _tx = t);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _deposit() async {
    final amt = await askAmount(context,
        title: 'Add demo funds', hint: 'Amount (demo)', confirm: 'ADD', quick: const [100, 500, 1000, 5000], max: app.config.maxDemoDeposit);
    if (amt == null) return;
    try {
      await app.backend.demoDeposit(amt);
      await _load();
      if (mounted) toast(context, 'Added ${inr(amt)} demo funds (simulated)');
    } on BackendException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  Future<void> _withdraw() async {
    final amt = await askAmount(context, title: 'Request demo withdrawal', hint: 'Amount (demo)', confirm: 'REQUEST', quick: const [100, 500], max: app.balance);
    if (amt == null) return;
    try {
      await app.backend.requestWithdrawal(amt);
      await _load();
      if (mounted) toast(context, 'Simulated withdrawal requested. No real payout is made.');
    } on BackendException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  IconData _icon(String t) {
    switch (t) {
      case 'deposit':
        return Icons.add_circle_outline;
      case 'withdrawal':
        return Icons.arrow_circle_up_outlined;
      case 'entry':
        return Icons.sports_esports;
      case 'reward':
        return Icons.emoji_events;
      default:
        return Icons.card_giftcard;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = const {
      'all': 'All',
      'deposit': 'Deposits',
      'withdrawal': 'Withdrawals',
      'entry': 'Entries',
      'reward': 'Rewards',
    };
    final list = _filter == 'all' ? _tx : _tx.where((t) => t.type == _filter).toList();
    final deposits = _tx.where((t) => t.type == 'deposit').fold(0.0, (a, t) => a + t.amount);
    final entries = _tx.where((t) => t.type == 'entry').fold(0.0, (a, t) => a - t.amount);
    final rewards = _tx.where((t) => t.type == 'reward').fold(0.0, (a, t) => a + t.amount);
    return RefreshIndicator(
      color: Gx.gold,
      backgroundColor: Gx.card,
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        Text('WALLET', style: Gx.display(22)),
        const SizedBox(height: 12),
        AppCard(
          glow: true,
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Text('DEMO BALANCE', style: Gx.label(color: Gx.goldLight)), const SizedBox(width: 8), const MiniTag('SIMULATED')]),
            const SizedBox(height: 6),
            ShaderMask(shaderCallback: (r) => Gx.goldGradient.createShader(r), child: Text(inr(app.balance), style: Gx.display(38, color: Colors.white))),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: GoldButton(label: 'ADD FUNDS', icon: Icons.add, compact: true, onPressed: _deposit)),
              const SizedBox(width: 10),
              Expanded(child: GoldButton(label: 'WITHDRAW', icon: Icons.arrow_upward, outlined: true, compact: true, onPressed: _withdraw)),
            ]),
          ]),
        ),
        const SizedBox(height: 10),
        const SimBanner(),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: StatTile(label: 'Deposited', value: inr(deposits), icon: Icons.south_west)),
          const SizedBox(width: 10),
          Expanded(child: StatTile(label: 'Entries', value: inr(entries), icon: Icons.confirmation_number_outlined)),
          const SizedBox(width: 10),
          Expanded(child: StatTile(label: 'Rewards', value: inr(rewards), icon: Icons.emoji_events_outlined, valueColor: Gx.goldLight)),
        ]),
        const SectionHeader('Wallet ledger'),
        SizedBox(
          height: 38,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final e in filters.entries)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(e.value, style: TextStyle(fontWeight: FontWeight.w700, color: _filter == e.key ? Colors.black : Gx.muted)),
                  selected: _filter == e.key,
                  selectedColor: Gx.gold,
                  backgroundColor: Gx.card,
                  side: const BorderSide(color: Gx.line),
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _filter = e.key),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: Gx.gold)))
        else if (list.isEmpty)
          AppCard(child: Text('No transactions here yet.', style: Gx.label(size: 13)))
        else
          for (final t in list)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: (t.amount >= 0 ? Gx.good : Gx.bad).withOpacity(0.14)),
                    child: Icon(_icon(t.type), color: t.amount >= 0 ? Gx.good : Gx.bad, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.note, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('${timeAgo(t.ts)}${t.displayStatus != null ? '  |  ${t.displayStatus}' : ''}', style: Gx.label(size: 11)),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(inr(t.amount, sign: true), style: TextStyle(fontWeight: FontWeight.w900, color: t.amount >= 0 ? Gx.good : Gx.bad)),
                    Text('Bal ${inr(t.balanceAfter)}', style: Gx.label(size: 10.5)),
                  ]),
                ]),
              ),
            ),
      ]),
    );
  }
}
