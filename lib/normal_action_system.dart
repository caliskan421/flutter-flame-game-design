import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'action_system.dart';

class NormalActionSystem extends ArenaActionSystem {
  // [bossOpeningDelay]: encounter'da zar başarısıyla (sessiz yaklaşma) boss'un
  // ilk saldırısını geciktirmek için. Varsayılan 0 → düz normal maç değişmez.
  const NormalActionSystem({this.bossOpeningDelay = 0});

  @override
  final double bossOpeningDelay;

  @override
  String get id => 'normal';

  @override
  bool get isTest => false;

  @override
  Vector2 bossBasePosition({
    required Rect arenaRect,
    required Vector2 playerPosition,
    required double groundY,
    required double standGap,
  }) {
    return Vector2(arenaRect.left + arenaRect.width * 0.74, groundY);
  }

  @override
  int get minPlayerHealth => 0;

  @override
  int get minBossHealth => 0;

  @override
  bool get playerCanDie => true;

  @override
  bool get bossCanDie => true;

  @override
  double get playerDodgeKnockbackImpulse => -540;

  @override
  double get playerAttackKnockbackImpulse => 300;

  @override
  double playerHitKnockbackImpulse(double dir, int damage) =>
      dir * 760 * (damage / 15);

  @override
  double playerRenderKnockback(double knockback) => knockback;

  @override
  bool get playerDodgeUsesProtectSprite => false;

  @override
  bool get upArrowParries => false;

  @override
  bool get downArrowParries => false;

  @override
  double get playerHealthRegenPerSecond => 0;

  @override
  double get bossHealthRegenPerSecond => 0;

  @override
  bool get lockBossToBaseX => false;

  @override
  bool get bossStartsBeatInPlace => false;

  @override
  bool get bossKeepsPressureInPlace => false;

  @override
  bool get bossUsesIdleApproachSprite => false;
}
