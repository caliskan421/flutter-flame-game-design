import 'dart:io';

import 'package:boss_parry_arena/game.dart';
import 'package:boss_parry_arena/normal_action_system.dart';
import 'package:boss_parry_arena/test_action_system.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('action systems', () {
    test('normal and test modes expose separate combat rules', () {
      const normal = NormalActionSystem();
      const test = TestActionSystem();

      expect(normal.id, 'normal');
      expect(test.id, 'test');
      expect(normal.isTest, isFalse);
      expect(test.isTest, isTrue);

      expect(normal.playerCanDie, isTrue);
      expect(normal.bossCanDie, isTrue);
      expect(test.playerCanDie, isFalse);
      expect(test.bossCanDie, isFalse);

      expect(normal.playerDodgeKnockbackImpulse, isNonZero);
      expect(test.playerDodgeKnockbackImpulse, 0);
      expect(normal.upArrowParries, isFalse);
      expect(test.upArrowParries, isTrue);
      expect(normal.downArrowParries, isFalse);
      expect(test.downArrowParries, isTrue);
      expect(normal.lockBossToBaseX, isFalse);
      expect(test.lockBossToBaseX, isTrue);
    });

    test('test action system can run system combo as a real match', () {
      const sandbox = TestActionSystem();
      const real = TestActionSystem(realMatch: true);

      expect(sandbox.playerCanDie, isFalse);
      expect(sandbox.playerHealthRegenPerSecond, greaterThan(0));
      expect(real.playerCanDie, isTrue);
      expect(real.bossCanDie, isTrue);
      expect(real.minPlayerHealth, 0);
      expect(real.minBossHealth, 0);
      expect(real.playerHealthRegenPerSecond, 0);
      expect(real.bossHealthRegenPerSecond, 0);
    });

    test('knight_1 repeated attacks use story scenario rules', () {
      expect(testAttackModeUsesScenarioRules(TestAttackMode.attack1), isTrue);
      expect(testAttackModeUsesScenarioRules(TestAttackMode.attack2), isTrue);
      expect(testAttackModeUsesScenarioRules(TestAttackMode.attack3), isTrue);
      expect(testAttackModeUsesScenarioRules(TestAttackMode.combo), isTrue);
      expect(testAttackModeUsesScenarioRules(TestAttackMode.defend), isFalse);
      expect(testAttackModeUsesScenarioRules(TestAttackMode.movement), isFalse);
    });

    test('stamina is unlimited only in the sandbox test arena', () {
      const sandbox = TestActionSystem();
      const real = TestActionSystem(realMatch: true);
      const normal = NormalActionSystem();

      // Serbest test (sandbox) → sınırsız; gerçek maç ve normal mod → sınırlı.
      expect(sandbox.unlimitedStamina, isTrue);
      expect(real.unlimitedStamina, isFalse);
      expect(normal.unlimitedStamina, isFalse);
    });

    test('stamina costs are positive and tuned by weight', () {
      const s = NormalActionSystem();
      expect(s.maxStamina, greaterThan(0));
      expect(s.dodgeStaminaCost, greaterThan(0));
      expect(s.heavyStaminaCost, greaterThan(s.lightStaminaCost));
      expect(s.heavyStaminaCost, greaterThan(s.dodgeStaminaCost));
      expect(s.blockStaminaCost, greaterThan(0));
      expect(s.parryStaminaRefund, greaterThan(0));
      expect(s.staminaRegenPerSecond, greaterThan(0));
    });

    test('boss base position is mode-specific', () {
      const normal = NormalActionSystem();
      const test = TestActionSystem();
      final arena = Rect.fromLTWH(30, 30, 800, 420);
      final player = Vector2(240, 330);

      final normalPos = normal.bossBasePosition(
        arenaRect: arena,
        playerPosition: player,
        groundY: 330,
        standGap: 82,
      );
      final testPos = test.bossBasePosition(
        arenaRect: arena,
        playerPosition: player,
        groundY: 330,
        standGap: 82,
      );

      expect(normalPos.x, arena.left + arena.width * 0.74);
      expect(testPos.x, player.x + 82);
      expect(normalPos.y, testPos.y);
    });

    test('boss AI okuma/aldatma yalnız gerçek maçta açık (09)', () {
      const sandbox = TestActionSystem();
      const real = TestActionSystem(realMatch: true);
      const normal = NormalActionSystem();

      // Serbest sandbox: deterministik pratik → tüm "okuyan/aldatan" davranışlar
      // kapalı (feint tuzağı, delayed jitter, kombo-içi adaptasyon, punish'ler).
      expect(sandbox.bossFeintTrap, isFalse);
      expect(sandbox.delayedWindupJitter, 0);
      expect(sandbox.bossInComboAdapt, isFalse);
      expect(sandbox.bossGreedPunish, isFalse);
      expect(sandbox.bossGuardBreakPunish, isFalse);

      // Gerçek maç (senaryo) ve normal mod: hepsi açık.
      for (final s in [real, normal]) {
        expect(s.bossFeintTrap, isTrue);
        expect(s.delayedWindupJitter, greaterThan(0));
        expect(s.bossInComboAdapt, isTrue);
        expect(s.bossGreedPunish, isTrue);
        expect(s.bossGuardBreakPunish, isTrue);
      }
    });

    test('09 ayar parametreleri makul aralıkta (09)', () {
      const s = NormalActionSystem();
      expect(s.feintBaitWindow, greaterThan(0));
      expect(s.feintBaitLock, greaterThan(s.feintBaitWindow));
      expect(s.greedPunishChance, inInclusiveRange(0, 1));
      expect(s.inComboAdaptChance, inInclusiveRange(0, 1));
    });

    test('fighter files read behavior from action systems', () {
      final playerSource = File(
        'lib/combat/sim/player.dart',
      ).readAsStringSync();
      // Faz F: boss davranışı boss.dart + `part of` modüllerine bölündü; AI/
      // temas/state-machine kodu artık part dosyalarında. Invariant (boss
      // game.testMode ile dallanmaz, davranışı game.actionSystem'den okur) bu
      // dosyaların TÜMÜ için geçerli olmalı.
      final bossSources = <String>[
        File('lib/combat/sim/boss.dart').readAsStringSync(),
        File('lib/combat/sim/boss_state_machine.dart').readAsStringSync(),
        File('lib/combat/sim/deathblow_controller.dart').readAsStringSync(),
        File('lib/combat/sim/boss_combat.dart').readAsStringSync(),
      ];
      final bossCombined = bossSources.join('\n');

      expect(playerSource, isNot(contains('game.testMode')));
      for (final src in bossSources) {
        expect(src, isNot(contains('game.testMode')));
      }
      expect(playerSource, contains('game.actionSystem'));
      expect(bossCombined, contains('game.actionSystem'));
    });
  });
}
