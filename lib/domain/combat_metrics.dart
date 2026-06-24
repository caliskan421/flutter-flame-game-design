// ============================================================================
//  COMBAT METRICS  —  tuning/debug için canlı sayaçlar (Faz 6)
// ----------------------------------------------------------------------------
//  Bir maçın hangi aksiyonla kazanıldığını/kaybedildiğini ve baskın stratejiyi
//  gözlemlemeye yarar. Debug overlay (` / 0) bunları gösterir.
// ============================================================================
class CombatMetrics {
  double fightDuration = 0;
  int playerDamageTaken = 0;
  int bossDamageTaken = 0;
  int bossPostureBreaks = 0;
  int parryAttempts = 0;
  int parrySuccesses = 0;
  int dodgeAttempts = 0;
  int dodgeSuccesses = 0;
  int attackWhiffs = 0;
  int lightHits = 0;
  int heavyHits = 0;
  int staminaEmptyDenials = 0;
  // --- BOSS AI & ADAPTASYON (09) ---
  int feintBaited = 0; // oyuncu aldatmaya kandı (erken savundu)
  int greedPunished = 0; // boss açık değilken saldıran oyuncu cezalandı
  int guardBreakPunished = 0; // postürü kırılan oyuncu garanti punish yedi

  void reset() {
    fightDuration = 0;
    playerDamageTaken = 0;
    bossDamageTaken = 0;
    bossPostureBreaks = 0;
    parryAttempts = 0;
    parrySuccesses = 0;
    dodgeAttempts = 0;
    dodgeSuccesses = 0;
    attackWhiffs = 0;
    lightHits = 0;
    heavyHits = 0;
    staminaEmptyDenials = 0;
    feintBaited = 0;
    greedPunished = 0;
    guardBreakPunished = 0;
  }
}
