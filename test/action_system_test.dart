import 'dart:io';

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

    test('fighter files read behavior from action systems', () {
      final playerSource = File('lib/player.dart').readAsStringSync();
      final bossSource = File('lib/boss.dart').readAsStringSync();

      expect(playerSource, isNot(contains('game.testMode')));
      expect(bossSource, isNot(contains('game.testMode')));
      expect(playerSource, contains('game.actionSystem'));
      expect(bossSource, contains('game.actionSystem'));
    });
  });
}
