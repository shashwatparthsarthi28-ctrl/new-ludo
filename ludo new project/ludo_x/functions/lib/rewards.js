'use strict';
/**
 * XP and daily-reward rules (server side). Mirrors lib/core/progress.dart and the
 * daily logic in lib/services/local_backend.dart. XP / levels never touch money;
 * the daily reward is a small simulated demo-coin bonus.
 */
const DAILY_AMOUNTS = [50, 75, 100, 150, 200, 300, 500];
const DAY_MS = 86400000;

const xpForMatch = (rank, completed) => (completed && rank >= 1 && rank <= 4 ? 20 + [60, 25, 10, 0][rank - 1] : 0);
const levelOf = (xp) => Math.floor(Math.sqrt(Math.max(0, xp) / 50)) + 1;

const dayKey = (ms) => new Date(ms).toISOString().slice(0, 10); // UTC day

/** user = { lastDaily: 'YYYY-MM-DD'|null, dailyStreak: number } */
function dailyStatus(user, nowMs) {
  const last = user.lastDaily || null;
  const streak = user.dailyStreak || 0;
  if (last === dayKey(nowMs)) {
    return { streak, claimedToday: true, nextDay: (streak % 7) + 1, doneCount: ((streak - 1) % 7) + 1 };
  }
  const eff = last === dayKey(nowMs - DAY_MS) ? streak : 0;
  return { streak: eff, claimedToday: false, nextDay: (eff % 7) + 1, doneCount: eff % 7 };
}

// Shop catalog (simulated currency only). Gems are earned in-game: +10 per level gained, +20 on day 7 of the daily streak.
const COIN_PACKS = {
  c500: { coins: 500, gems: 50 },
  c1000: { coins: 1000, gems: 90 },
  c2500: { coins: 2500, gems: 200 },
  c5000: { coins: 5000, gems: 350 },
};
const SHOP_ITEMS = {
  dice: { classic: 0, gold: 60, neon: 90, ruby: 120 },
  theme: { classic: 0, sunset: 80, forest: 80, ocean: 100 },
};
const GEMS_PER_LEVEL = 10;
const DAY7_GEMS = 20;
const STARTER_GEMS = 120;

module.exports = { COIN_PACKS, SHOP_ITEMS, GEMS_PER_LEVEL, DAY7_GEMS, STARTER_GEMS, DAILY_AMOUNTS, xpForMatch, levelOf, dayKey, dailyStatus };
