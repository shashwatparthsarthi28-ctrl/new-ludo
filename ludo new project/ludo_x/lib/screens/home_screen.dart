import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/models.dart';
import 'match_log_screen.dart';

class MatchTile extends StatelessWidget {
  final MatchRecord record;
  const MatchTile({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final win = record.rank == 1;
    final paid = record.entry > 0;
    final net = record.net;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (win ? Gx.gold : Gx.cardHi),
            ),
            child: Text(ordinal(record.rank), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: win ? Colors.black : Gx.text)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(modeTitle(record.mode), style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('${timeAgo(record.ts)}${record.completed ? '' : '  |  abandoned'}${record.difficulty.isNotEmpty && record.difficulty != '-' ? '  |  ${record.difficulty}' : ''}',
                  style: Gx.label(size: 11), overflow: TextOverflow.ellipsis),
            ]),
          ),
          Text(paid ? inr(net, sign: true) : 'Free',
              style: TextStyle(fontWeight: FontWeight.w900, color: !paid ? Gx.muted : (net >= 0 ? Gx.good : Gx.bad))),
        ]),
      ),
    );
  }
}

class LeaderTile extends StatelessWidget {
  final int rank;
  final LeaderEntry entry;
  final bool me;
  const LeaderTile({super.key, required this.rank, required this.entry, this.me = false});

  @override
  Widget build(BuildContext context) {
    const medals = [Color(0xFFFFD54F), Color(0xFFCFD8DC), Color(0xFFCD7F32)];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        glow: me,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          SizedBox(
            width: 30,
            child: rank <= 3 ? Icon(Icons.workspace_premium, color: medals[rank - 1]) : Text('$rank', style: const TextStyle(fontWeight: FontWeight.w900, color: Gx.muted)),
          ),
          AvatarView(index: entry.avatar, size: 38, ring: false),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(entry.username, style: const TextStyle(fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
                if (me) ...[const SizedBox(width: 6), const MiniTag('YOU')],
                if (entry.sample) ...[const SizedBox(width: 6), const MiniTag('SAMPLE', color: Gx.muted)],
              ]),
              Text('${entry.wins} wins', style: Gx.label(size: 11)),
            ]),
          ),
          Text(inr(entry.earnings, sign: true), style: TextStyle(fontWeight: FontWeight.w900, color: entry.earnings >= 0 ? Gx.goldLight : Gx.bad)),
        ]),
      ),
    );
  }
}
