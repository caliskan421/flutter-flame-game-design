// Faz E — Normal (ölümlü) maç akışı.
// İki modun ölüm kurallarının BİRBİRİNE SIZMADIĞINI, eşiklerin getter'dan
// geldiğini ve boss seçiminin geçerli roster'dan olduğunu doğrular.
import 'dart:io';

import 'package:boss_parry_arena/characters.dart';
import 'package:boss_parry_arena/domain/game_session.dart';
import 'package:boss_parry_arena/normal_action_system.dart';
import 'package:boss_parry_arena/test_action_system.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normal match death rules', () {
    test('NormalActionSystem: ikisi de ölebilir, min can 0', () {
      const normal = NormalActionSystem();
      expect(normal.playerCanDie, isTrue);
      expect(normal.bossCanDie, isTrue);
      expect(normal.minPlayerHealth, 0);
      expect(normal.minBossHealth, 0);
    });

    test('TestActionSystem(realMatch=false): ölümsüz, min can 1', () {
      const sandbox = TestActionSystem(realMatch: false);
      expect(sandbox.playerCanDie, isFalse);
      expect(sandbox.bossCanDie, isFalse);
      expect(sandbox.minPlayerHealth, 1);
      expect(sandbox.minBossHealth, 1);
    });

    test('TestActionSystem(realMatch=true): MEVCUT senaryo testi yolu ölümlü',
        () {
      // Bu, normal modun (NormalActionSystem) İKİNCİ bir yolu DEĞİL; Faz E
      // öncesinden var olan combat-senaryo test akışıdır (startCombatScenarioIntro
      // → _setTestRealMatch(true)). isTest=true kalır → normalMatchMode'a girmez.
      const deadly = TestActionSystem(realMatch: true);
      expect(deadly.isTest, isTrue);
      expect(deadly.playerCanDie, isTrue);
      expect(deadly.bossCanDie, isTrue);
      expect(deadly.minPlayerHealth, 0);
      expect(deadly.minBossHealth, 0);
    });

    test('iki mod birbirine sızmaz: sandbox sandbox kalır, normal normal kalır',
        () {
      // Aynı türden iki ayrı örnek; biri diğerinin kuralını DEĞİŞTİREMEZ.
      const sandbox = TestActionSystem();
      const normal = NormalActionSystem();
      expect(sandbox.isTest, isTrue);
      expect(normal.isTest, isFalse);
      // Sandbox ölümsüzlüğü; normal mod ölümlülüğü — hiçbir paylaşılan durum yok.
      expect(sandbox.playerCanDie || sandbox.bossCanDie, isFalse);
      expect(normal.playerCanDie && normal.bossCanDie, isTrue);
      // Sandbox'ta yerinde döngü açık, normal modda kapalı.
      expect(sandbox.lockBossToBaseX, isTrue);
      expect(normal.lockBossToBaseX, isFalse);
      // Sandbox sınırsız stamina; normal mod sınırlı.
      expect(sandbox.unlimitedStamina, isTrue);
      expect(normal.unlimitedStamina, isFalse);
    });
  });

  group('boss roster for normal match', () {
    test('seçilebilir boss geçerli roster ve oyuncuyu içermez', () {
      expect(kOpponents, isNotEmpty);
      for (final boss in kOpponents) {
        expect(kCharacters, contains(boss));
        expect(boss.id, isNot(kPlayerDef.id));
      }
      expect(kOpponents.map((e) => e.id), isNot(contains(kPlayerDef.id)));
      // kOpponents, kOpponentIds ile birebir tutarlı (sıra dahil).
      expect(kOpponents.map((e) => e.id).toList(), kOpponentIds);
    });
  });

  // game.dart davranış değişmezleri — repo'nun mevcut kaynak-seviyesi test
  // idiomu ('fighter files read behavior'). Canlı FlameGame pump etmeden,
  // normal modun TEK yerden bağlandığını ve eşiklerin getter'dan okunduğunu
  // (hard-code edilmediğini) kanıtlar.
  group('game.dart wiring guards', () {
    final source = File('lib/game.dart').readAsStringSync();

    test('NormalActionSystem yalnız tek yerden (mod seçimi) set edilir', () {
      expect(
        'actionSystem = const NormalActionSystem()'.allMatches(source).length,
        1,
      );
    });

    test('win/loss eşikleri actionSystem getter\'larından okunur, hard-code değil',
        () {
      expect(source, contains('actionSystem.playerCanDie'));
      expect(source, contains('actionSystem.bossCanDie'));
      expect(source, contains('actionSystem.minPlayerHealth'));
      expect(source, contains('actionSystem.minBossHealth'));
      // Eski hard-code eşik kaldırıldı.
      expect(source, isNot(contains('player.health <= 0')));
      expect(source, isNot(contains('b.health <= 0')));
    });
  });

  group('GameSession (saf durum)', () {
    test('selectBoss sonucu sıfırlar, recordResult sonucu tutar', () {
      final session = GameSession();
      expect(session.selectedBossId, isNull);
      expect(session.lastResult, MatchResult.none);

      session.selectBoss(kOpponentIds.first);
      expect(session.selectedBossId, kOpponentIds.first);
      expect(session.lastResult, MatchResult.none);

      session.recordResult(MatchResult.won);
      expect(session.lastResult, MatchResult.won);

      // Yeni boss seçimi önceki sonucu temizler.
      session.selectBoss(kOpponentIds.last);
      expect(session.selectedBossId, kOpponentIds.last);
      expect(session.lastResult, MatchResult.none);
    });
  });
}
