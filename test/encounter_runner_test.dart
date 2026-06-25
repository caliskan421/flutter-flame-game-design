import 'package:boss_parry_arena/app/flow/encounter_runner.dart';
import 'package:boss_parry_arena/core/rng.dart';
import 'package:boss_parry_arena/domain/dice_service.dart';
import 'package:boss_parry_arena/domain/encounter.dart';
import 'package:boss_parry_arena/domain/scenario_effect.dart';
import 'package:boss_parry_arena/domain/scenario_state.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeHost implements EncounterHost {
  final List<String> calls = [];
  DiceResult? lastDice;
  CombatStep? lastCombat;
  RewardStep? lastReward;

  @override
  void showDialogue(DialogueNodeDef node) => calls.add('dialogue:${node.id}');
  @override
  void showChoice(ChoiceDef choice) => calls.add('choice');
  @override
  void showDiceCheck(DiceCheckDef check, DiceResult result) {
    lastDice = result;
    calls.add('dice:${result.success ? "ok" : "fail"}');
  }

  @override
  void startCombat(CombatStep step) {
    lastCombat = step;
    calls.add('combat:${step.bossId}');
  }

  @override
  void showReward(RewardStep step) {
    lastReward = step;
    calls.add('reward');
  }

  @override
  void onCombatLost(EncounterDef encounter) => calls.add('lost');
  @override
  void onEncounterComplete(EncounterDef encounter) => calls.add('complete');
}

EncounterDef _encounter() => const EncounterDef(
      id: 'ash_gate',
      title: 'Ash Gate',
      steps: [
        DialogueStep(DialogueNodeDef('intro', [DialogueLine('Bekçi', 'Dur!')])),
        ChoiceStep(ChoiceDef('Nasıl yaklaşırsın?', [
          ChoiceOption('Gölgeden', effects: [SetStat('stealth', 10)]),
          ChoiceOption('Doğrudan', effects: [SetStat('stealth', -10)]),
        ])),
        DiceCheckStep(DiceCheckDef(
          id: 'sneak',
          stat: 'stealth',
          difficulty: 12,
          onSuccess: [SetFlag('approached_silently')],
          onFailure: [SetFlag('spotted')],
        )),
        CombatStep('knight_1'),
        RewardStep(
          title: 'Zafer',
          text: 'Kapı senin.',
          effects: [SetFlag('boss_knight_1_defeated'), GiveResource('honor', 1)],
        ),
      ],
    );

void main() {
  group('EncounterRunner', () {
    test('tam akış: diyalog→seçim→zar(başarı)→combat→win→ödül→tamam', () {
      final state = ScenarioState();
      final host = FakeHost();
      final runner = EncounterRunner(
        def: _encounter(),
        state: state,
        rng: Rng.seeded(1),
        host: host,
      );

      runner.start();
      expect(host.calls.last, 'dialogue:intro');
      runner.next();
      expect(host.calls.last, 'choice');
      runner.choose(0); // Gölgeden → stealth +10
      expect(state.stat('stealth'), 10);
      expect(host.calls.last, 'dice:ok'); // 1d20+10 >= 12 (seed 1)
      expect(state.hasFlag('approached_silently'), isTrue);
      runner.next();
      expect(host.calls.last, 'combat:knight_1');
      runner.onCombatResult(true);
      expect(host.calls.last, 'reward');
      expect(state.hasFlag('boss_knight_1_defeated'), isTrue);
      expect(state.resource('honor'), 1);
      runner.next();
      expect(host.calls.last, 'complete');
      expect(state.isCompleted('ash_gate'), isTrue);
    });

    test('doğrudan yaklaşım → zar başarısız → spotted, sessiz flag yok', () {
      final state = ScenarioState();
      final host = FakeHost();
      final runner = EncounterRunner(
        def: _encounter(),
        state: state,
        rng: Rng.seeded(1),
        host: host,
      );
      runner.start();
      runner.next();
      runner.choose(1); // Doğrudan → stealth -10 → 1d20-10 max 10 < 12 → fail
      expect(host.calls.last, 'dice:fail');
      expect(state.hasFlag('spotted'), isTrue);
      expect(state.hasFlag('approached_silently'), isFalse);
    });

    test('combat kaybı → onCombatLost; retry aynı combat adımını başlatır', () {
      final state = ScenarioState();
      final host = FakeHost();
      final runner = EncounterRunner(
        def: _encounter(),
        state: state,
        rng: Rng.seeded(1),
        host: host,
      );
      runner.start();
      runner.next(); // choice
      runner.choose(0); // dice
      runner.next(); // combat
      expect(host.calls.last, 'combat:knight_1');
      runner.onCombatResult(false);
      expect(host.calls.last, 'lost');
      // runner hâlâ combat adımında; reward verilmedi
      expect(state.hasFlag('boss_knight_1_defeated'), isFalse);
      runner.retryCombat();
      expect(host.calls.last, 'combat:knight_1');
      // tekrar kazanınca akış devam eder
      runner.onCombatResult(true);
      expect(host.calls.last, 'reward');
    });

    test("start() geçici flag'leri temizler (tekrar oynatmada sızmaz)", () {
      const def = EncounterDef(
        id: 'e',
        title: 'E',
        clearFlagsOnStart: ['approached_silently', 'alerted_guard'],
        steps: [DialogueStep(DialogueNodeDef('d', [DialogueLine('x', 'y')]))],
      );
      // Önceki oynatmadan kalan flag.
      final state = ScenarioState()..setFlag('approached_silently');
      final runner = EncounterRunner(
        def: def,
        state: state,
        rng: Rng.seeded(1),
        host: FakeHost(),
      );
      runner.start();
      expect(state.hasFlag('approached_silently'), isFalse);
    });

    test("kalıcı ilerleme flag'i start()ta temizlenmez", () {
      const def = EncounterDef(
        id: 'e',
        title: 'E',
        clearFlagsOnStart: ['approached_silently'],
        steps: [DialogueStep(DialogueNodeDef('d', [DialogueLine('x', 'y')]))],
      );
      final state = ScenarioState()..setFlag('boss_knight_1_defeated');
      EncounterRunner(def: def, state: state, rng: Rng.seeded(1), host: FakeHost())
          .start();
      expect(state.hasFlag('boss_knight_1_defeated'), isTrue);
    });

    test('ödül yalnız İLK tamamlamada verilir (tekrar oynamada çift ödül yok)', () {
      final state = ScenarioState();
      void playToWin() {
        final runner = EncounterRunner(
          def: _encounter(),
          state: state,
          rng: Rng.seeded(1),
          host: FakeHost(),
        );
        runner.start();
        runner.next(); // choice
        runner.choose(0); // dice
        runner.next(); // combat
        runner.onCombatResult(true); // reward
        runner.next(); // complete
      }

      playToWin();
      expect(state.resource('honor'), 1);
      expect(state.isCompleted('ash_gate'), isTrue);

      playToWin(); // tekrar oyna — completedEncounters kalıcı → ödül tekrar verilmez
      expect(state.resource('honor'), 1);
    });

    test('ödül + tamamlandı ATOMİK: reward gösterilince (kapanmadan) completed', () {
      final state = ScenarioState();
      final runner = EncounterRunner(
        def: _encounter(),
        state: state,
        rng: Rng.seeded(1),
        host: FakeHost(),
      );
      runner.start();
      runner.next(); // choice
      runner.choose(0); // dice
      runner.next(); // combat
      runner.onCombatResult(true); // reward gösterildi — ama next() ÇAĞRILMADI
      // Reward ekranındayken "çökme" simülasyonu: completed + honor zaten kalıcı.
      expect(state.isCompleted('ash_gate'), isTrue);
      expect(state.resource('honor'), 1);
    });

    test('onStateChanged efekt/tamamlamada tetiklenir (kalıcılık kancası)', () {
      var changes = 0;
      final state = ScenarioState();
      final runner = EncounterRunner(
        def: _encounter(),
        state: state,
        rng: Rng.seeded(1),
        host: FakeHost(),
        onStateChanged: () => changes++,
      );
      runner.start();
      runner.next();
      runner.choose(0); // choice efektleri → +1
      runner.next();
      runner.onCombatResult(true); // reward efektleri → +1
      runner.next(); // complete → +1
      expect(changes, greaterThanOrEqualTo(3));
    });

    test('seedli zar deterministik (aynı seed → aynı sonuç)', () {
      DiceResult run(int seed) {
        final state = ScenarioState();
        final host = FakeHost();
        final runner = EncounterRunner(
          def: _encounter(),
          state: state,
          rng: Rng.seeded(seed),
          host: host,
        );
        runner.start();
        runner.next();
        runner.choose(0);
        return host.lastDice!;
      }

      expect(run(5).total, run(5).total);
    });
  });
}
