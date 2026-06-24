// CombatPresenter semantik-olay → metrik eşlemesi testleri (Faz B). Bu, eski
// `game.metrics.*` artışlarının artık event üzerinden BİREBİR aynı sayaca
// gittiğini kilitler (davranış-koruma kanıtı). Yalnız metrik dalları test edilir;
// sunum (spawn/Sfx) dalları mount edilmiş bir Flame oyunu gerektirir → elle
// duman testine (flutter run) bırakılır.

import 'package:boss_parry_arena/combat/rules/combat_event.dart';
import 'package:boss_parry_arena/core/event_bus.dart';
import 'package:boss_parry_arena/game.dart';
import 'package:boss_parry_arena/presentation/combat_presenter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CombatPresenter metrik eşlemesi', () {
    late BossArenaGame game;
    late EventBus bus;

    setUp(() {
      game = BossArenaGame();
      bus = EventBus();
      CombatPresenter(bus, game);
    });

    test('PostureBroken → bossPostureBreaks++', () {
      bus.emit(const PostureBroken());
      bus.emit(const PostureBroken());
      expect(game.metrics.bossPostureBreaks, 2);
    });

    test('DamageApplied(toBoss) → bossDamageTaken += amount', () {
      bus.emit(const DamageApplied(15, toBoss: true));
      bus.emit(const DamageApplied(7, toBoss: true));
      expect(game.metrics.bossDamageTaken, 22);
    });

    test('DamageApplied(oyuncuya) boss sayacını DEĞİŞTİRMEZ', () {
      bus.emit(const DamageApplied(40, toBoss: false));
      expect(game.metrics.bossDamageTaken, 0);
    });

    test('ParrySucceeded / DodgeSucceeded sayaçları artar', () {
      bus.emit(const ParrySucceeded(perfect: true));
      bus.emit(const DodgeSucceeded(perfect: false));
      expect(game.metrics.parrySuccesses, 1);
      expect(game.metrics.dodgeSuccesses, 1);
    });

    test('MetricRecorded doğru sayaca yazar', () {
      bus.emit(const MetricRecorded(MetricKind.feintBaited));
      bus.emit(const MetricRecorded(MetricKind.greedPunished));
      bus.emit(const MetricRecorded(MetricKind.guardBreakPunished));
      expect(game.metrics.feintBaited, 1);
      expect(game.metrics.greedPunished, 1);
      expect(game.metrics.guardBreakPunished, 1);
    });

    test('metrik karşılığı olmayan semantik olaylar no-op (sayaç sabit)', () {
      bus.emit(const Deathblow(lethal: true));
      bus.emit(const PhaseChanged(2));
      bus.emit(const BossDefeated('knight_1'));
      expect(game.metrics.bossDamageTaken, 0);
      expect(game.metrics.bossPostureBreaks, 0);
    });
  });
}
