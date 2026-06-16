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
}
