// ============================================================================
//  COMBAT PRESENTER  —  combat olaylarının TEK sunum noktası (Faz B)
// ----------------------------------------------------------------------------
//  `EventBus`'a abone olur; her `CombatEvent`'i bugün boss.dart'ın doğrudan
//  yaptığı Sfx/popup/spark/slow-mo/metrik çağrısına eşler. Combat kararı artık
//  sunumu bilmez (D3); tüm yan etki burada toplanır.
//
//  Davranış-koruyan: olaylar boss'taki eski çağrı sırasıyla yayıldığı için
//  ses/slow-mo zamanlaması birebir aynıdır.
// ============================================================================
import 'dart:ui' show Color;

import 'package:boss_parry_arena/app/game/boss_arena_game.dart';
import 'package:boss_parry_arena/combat/rules/combat_event.dart';
import 'package:boss_parry_arena/core/event_bus.dart';
import 'package:boss_parry_arena/presentation/audio.dart';
import 'package:boss_parry_arena/presentation/fx.dart';

class CombatPresenter {
  final BossArenaGame game;
  late final void Function() _unsubscribe;

  CombatPresenter(EventBus bus, this.game) {
    _unsubscribe = bus.subscribe(_onEvent);
  }

  void dispose() => _unsubscribe();

  void _onEvent(CombatEvent event) {
    switch (event) {
      // --- SUNUM KOMUTLARI (boss'taki çağrının birebir karşılığı) ---------
      case SfxRequested(:final cue):
        _playSfx(cue);
      case PopupRequested(
        :final position,
        :final text,
        :final color,
        :final fontSize,
        :final rise,
      ):
        if (color != null) {
          game.spawnPopup(
            position,
            text,
            color: color,
            fontSize: fontSize,
            rise: rise,
          );
        } else {
          game.spawnPopup(position, text, fontSize: fontSize, rise: rise);
        }
      case ComboTextRequested(:final position, :final text):
        game.add(ComboText(position, text));
      case SparkRequested(:final position, :final color):
        game.spawnSpark(position, color);
      case PostureBreakFxRequested(:final position, :final color, :final scale):
        if (color != null) {
          game.spawnPostureBreak(position, color: color, scale: scale);
        } else {
          game.spawnPostureBreak(position, scale: scale);
        }
      case VignetteRequested(:final color, :final maxLife, :final peakAlpha):
        // game.spawnVignette varsayılanları: 0xFFC0271E / 0.6 / 92.
        game.spawnVignette(
          color: color ?? const Color(0xFFC0271E),
          maxLife: maxLife ?? 0.6,
          peakAlpha: peakAlpha ?? 92,
        );
      case HitstopRequested(:final seconds):
        game.requestHitstop(seconds);
      case SlowmoRequested(:final duration, :final scale):
        game.requestSlowmo(duration, scale);
      case ShakeRequested(:final amplitude, :final duration):
        game.requestShake(amplitude, duration);

      // --- SEMANTİK OLAYLAR → metrik (+ ileride domain abonesi, Faz G) -----
      case PostureBroken():
        game.metrics.bossPostureBreaks++;
      case DamageApplied(:final amount, :final toBoss):
        if (toBoss) game.metrics.bossDamageTaken += amount;
      case ParrySucceeded():
        game.metrics.parrySuccesses++;
      case DodgeSucceeded():
        game.metrics.dodgeSuccesses++;
      case MetricRecorded(:final kind, :final amount):
        _recordMetric(kind, amount);

      // Henüz sunum/metrik karşılığı olmayan semantik olaylar: domain (Faz G)
      // abone olana kadar no-op. `sealed` switch'i tam tutmak için burada.
      case Deathblow():
        break;
      case PhaseChanged():
        break;
      case BossDefeated():
        break;
    }
  }

  void _playSfx(SfxCue cue) {
    switch (cue) {
      case SfxCue.hit:
        Sfx.hit();
      case SfxCue.postureBreak:
        Sfx.postureBreak();
      case SfxCue.swordDrop:
        Sfx.swordDrop();
      case SfxCue.phaseShift:
        Sfx.phaseShift();
      case SfxCue.whiff:
        Sfx.whiff();
      case SfxCue.deathblow:
        Sfx.deathblow();
      case SfxCue.parryPerfect:
        Sfx.parryPerfect();
      case SfxCue.parryLate:
        Sfx.parryLate();
      case SfxCue.dodge:
        Sfx.dodge();
      case SfxCue.heavyHit:
        Sfx.heavyHit();
      case SfxCue.parry:
        Sfx.parry();
      case SfxCue.block:
        Sfx.block();
    }
  }

  void _recordMetric(MetricKind kind, int amount) {
    switch (kind) {
      case MetricKind.feintBaited:
        game.metrics.feintBaited += amount;
      case MetricKind.greedPunished:
        game.metrics.greedPunished += amount;
      case MetricKind.guardBreakPunished:
        game.metrics.guardBreakPunished += amount;
    }
  }
}
