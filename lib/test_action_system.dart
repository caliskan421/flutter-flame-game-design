import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'action_system.dart';

class TestActionSystem extends ArenaActionSystem {
  const TestActionSystem({this.realMatch = false});

  final bool realMatch;

  @override
  String get id => 'test';

  @override
  bool get isTest => true;

  @override
  Vector2 bossBasePosition({
    required Rect arenaRect,
    required Vector2 playerPosition,
    required double groundY,
    required double standGap,
  }) {
    return Vector2(playerPosition.x + standGap, groundY);
  }

  @override
  int get minPlayerHealth => realMatch ? 0 : 1;

  @override
  int get minBossHealth => realMatch ? 0 : 1;

  @override
  bool get playerCanDie => realMatch;

  @override
  bool get bossCanDie => realMatch;

  @override
  double get playerDodgeKnockbackImpulse => 0;

  @override
  double get playerAttackKnockbackImpulse => 0;

  @override
  double playerHitKnockbackImpulse(double dir, int damage) => 0;

  @override
  double playerRenderKnockback(double knockback) => 0;

  @override
  bool get playerDodgeUsesProtectSprite => true;

  @override
  bool get upArrowParries => true;

  @override
  bool get downArrowParries => true;

  @override
  double get playerHealthRegenPerSecond => realMatch ? 0 : 18;

  @override
  double get bossHealthRegenPerSecond => realMatch ? 0 : 22;

  @override
  bool get lockBossToBaseX => true;

  @override
  bool get bossStartsBeatInPlace => true;

  @override
  bool get bossKeepsPressureInPlace => true;

  @override
  bool get bossUsesIdleApproachSprite => true;

  // Serbest test (sandbox) → sınırsız stamina; senaryo gerçek maçı → sınırlı.
  @override
  bool get unlimitedStamina => !realMatch;

  // Faz geçişi sahnesi yalnız gerçek maçta; serbest sandbox pratiği bölünmesin (08).
  @override
  bool get bossPhaseStaging => realMatch;
}
