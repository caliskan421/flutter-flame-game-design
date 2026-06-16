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

  // --- BOSS AI & ADAPTASYON / ALDATMA (09_boss_ai_adaptasyon_sistemi) --------
  // Bu parametreler 14_zorluk_erisilebilirlik ile ölçeklenmek üzere getter olarak
  // durur; sandbox'ta öğrenme döngüsü bozulmasın diye agresif okumalar kapatılır.

  // Feint (aldatma) GERÇEK bir tuzak mı? Erken/önceden savunan oyuncuyu kısa
  // recovery'ye sokar; arkasından gelen gerçek beat punish eder.
  bool get bossFeintTrap => true;
  // Erken basışın "yem yuttu" sayıldığı pencere (feint sahte-temasından önce).
  double get feintBaitWindow => 0.20;
  // Tuzağa düşen oyuncunun savunma kilidi (cooldown) süresi. Hemen ardından gelen
  // (hızlandırılmış) gerçek beat'in temasını kapsayacak kadar uzun olmalı.
  double get feintBaitLock => 0.55;

  // Delayed (ritim kırma): windup'a eklenen runtime jitter büyüklüğü. Çoğunlukla
  // pozitif (geciktirir); küçük negatif pay metronomu tamamen kırar.
  double get delayedWindupJitter => 0.20;

  // Kombo İÇİNDE anlık adaptasyon: oyuncunun son cevaplarına göre sıradaki beat'i
  // dinamik dönüştür (parry'ciye feint/guardBreak, dodge'cuya tracking).
  bool get bossInComboAdapt => true;
  // Bir beat'in dönüştürülme olasılığı (eğilim güçlüyken).
  double get inComboAdaptChance => 0.5;

  // Greed punish: boss açık değilken saldıran oyuncuyu (risksiz poke yerine)
  // hızlı bir karşı-beat ile cezalandırma olasılığı.
  bool get bossGreedPunish => true;
  double get greedPunishChance => 0.5;

  // Guard-break punish: oyuncunun postürü kırılıp açık kalınca boss GARANTİ
  // hızlı punish beat başlatır.
  bool get bossGuardBreakPunish => true;
}
