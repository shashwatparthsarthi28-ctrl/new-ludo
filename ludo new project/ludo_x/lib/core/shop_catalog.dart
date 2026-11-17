import 'package:flutter/material.dart';

/// Shop catalog. Mirrors COIN_PACKS / SHOP_ITEMS in functions/lib/rewards.js.
/// Gems are a SIMULATED in-game currency earned by levelling up (+10 per level)
/// and on day 7 of the daily streak (+20). They can never be bought with money.
const int kGemsPerLevel = 10;
const int kDay7Gems = 20;
const int kStarterGems = 120;

class CoinPack {
  final String id;
  final int coins;
  final int gems;
  const CoinPack(this.id, this.coins, this.gems);
}

const List<CoinPack> kCoinPacks = [
  CoinPack('c500', 500, 50),
  CoinPack('c1000', 1000, 90),
  CoinPack('c2500', 2500, 200),
  CoinPack('c5000', 5000, 350),
];

class DiceSkin {
  final String id;
  final String name;
  final int price;
  final Color face1;
  final Color face2;
  final Color border;
  final Color pip;
  const DiceSkin(this.id, this.name, this.price, this.face1, this.face2, this.border, this.pip);
}

const List<DiceSkin> kDiceSkins = [
  DiceSkin('classic', 'Classic', 0, Color(0xFFFFFFF6), Color(0xFFE4DCC4), Color(0xFFBDB6F5), Color(0xFF151515)),
  DiceSkin('gold', 'Golden', 60, Color(0xFFFFE9A8), Color(0xFFE0A82E), Color(0xFFFFF3C4), Color(0xFF5A3A00)),
  DiceSkin('neon', 'Neon', 90, Color(0xFF1B1B3A), Color(0xFF0E0E24), Color(0xFF39FF14), Color(0xFF39FF14)),
  DiceSkin('ruby', 'Ruby', 120, Color(0xFFFF7A90), Color(0xFFC0143C), Color(0xFFFFC2CE), Color(0xFFFFFFFF)),
];

class BoardTheme {
  final String id;
  final String name;
  final int price;
  final Color base;
  final Color track;
  final Color frame;
  const BoardTheme(this.id, this.name, this.price, this.base, this.track, this.frame);
}

const List<BoardTheme> kBoardThemes = [
  BoardTheme('classic', 'Classic', 0, Color(0xFFFFF6DC), Color(0xFFFFFFFF), Color(0xFFFFC21A)),
  BoardTheme('sunset', 'Sunset', 80, Color(0xFFFFE0CC), Color(0xFFFFF3E8), Color(0xFFFF7043)),
  BoardTheme('forest', 'Forest', 80, Color(0xFFDDF0D2), Color(0xFFF4FFF0), Color(0xFF2E7D32)),
  BoardTheme('ocean', 'Ocean', 100, Color(0xFFD0ECFF), Color(0xFFF2FAFF), Color(0xFF1976D2)),
];

DiceSkin diceSkinOf(String id) => kDiceSkins.firstWhere((s) => s.id == id, orElse: () => kDiceSkins.first);
BoardTheme boardThemeOf(String id) => kBoardThemes.firstWhere((t) => t.id == id, orElse: () => kBoardThemes.first);

/// Price of an item or -1 if unknown. kind: 'dice' | 'theme'.
int shopPrice(String kind, String id) {
  if (kind == 'dice') {
    for (final s in kDiceSkins) {
      if (s.id == id) return s.price;
    }
  } else if (kind == 'theme') {
    for (final t in kBoardThemes) {
      if (t.id == id) return t.price;
    }
  }
  return -1;
}
