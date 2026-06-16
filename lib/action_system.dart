import 'package:flame/components.dart';
import 'package:flutter/material.dart';

abstract class ArenaActionSystem {
  const ArenaActionSystem();

  String get id;
  bool get isTest;

  Vector2 bossBasePosition({
    required Rect arenaRect,
    required Vector2 playerPosition,
    required double groundY,
    required double standGap,
  });

  int get minPlayerHealth;
  int get minBossHealth;
  bool get playerCanDie;
  bool get bossCanDie;

  double get playerDodgeKnockbackImpulse;
  double get playerAttackKnockbackImpulse;
  double playerHitKnockbackImpulse(double dir, int damage);
  double playerRenderKnockback(double knockback);
  bool get playerDodgeUsesProtectSprite;
  bool get upArrowParries;
  bool get downArrowParries;

  double get playerHealthRegenPerSecond;
  double get bossHealthRegenPerSecond;

  bool get lockBossToBaseX;
  bool get bossStartsBeatInPlace;
  bool get bossKeepsPressureInPlace;
  bool get bossUsesIdleApproachSprite;

  // --- STAMINA / KAYNAK (01_stamina_kaynak_sistemi) -------------------------
  // Oyuncunun dodge / ağır saldırı / blok için harcadığı eylem bütçesi. Test
  // sandbox'ında sınırsız tutulur (mevcut serbest test akışı bozulmasın); gerçek
  // maçta sınırlanır. Alt sınıflar yalnız değişeni override eder.
  bool get unlimitedStamina => !isTest ? false : true;

  double get maxStamina => 100;
  double get staminaRegenPerSecond => 26;
  double get staminaRegenDelay => 0.55; // son aksiyondan sonra regen gecikmesi
  double get lowStaminaFraction => 0.15; // bu oranın altı = "yorgun"

  double get dodgeStaminaCost => 22;
  double get heavyStaminaCost => 30;
  double get lightStaminaCost => 8;
  double get blockStaminaCost => 12;
  double get parryStaminaRefund => 6; // başarılı parry küçük iade

  // --- DEATHBLOW / FAZ / GAME-FEEL (06 / 08 / 11) -----------------------------
  // Bu HP eşiğinin altında denge kırılırsa infaz ANINDA öldürür (riskli ama
  // yetenekli oyuncuyu ödüllendirir). Üstündeyse segment siler + faz geçişi.
  int get bossExecuteThresholdHp => 30;

  // Faz eşiği aşılınca kısa, dokunulmaz "faz geçişi" sahnesi oynatılsın mı?
  // Serbest sandbox'ta kapalı (pratik döngüsü bölünmesin); gerçek maçta açık.
  bool get bossPhaseStaging => true;

  // Ekran sarsıntısı genel çarpanı (erişilebilirlik için kısılabilir/kapatılabilir).
  double get screenShakeScale => 1.0;

  // Deathblow sinematik yavaşlatması (hitstop'tan AYRI, daha uzun ve daha hafif yol).
  double get deathblowSlowmoScale => 0.28;
  double get deathblowSlowmoDuration => 0.55;
  // Faz geçişi sahnesinin süresi (dokunulmaz).
  double get phaseTransitionDuration => 1.05;
}
