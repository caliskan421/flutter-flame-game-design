// ============================================================================
//  COMBAT EVENT  —  sealed combat olay hiyerarşisi (Faz B)
// ----------------------------------------------------------------------------
//  `CombatEvent`, combat kararının dış dünyaya (sunum + domain) tek konuşma
//  biçimidir. `sealed` olduğu için tüketici (CombatPresenter) `switch`'inde bir
//  dal unutursa derleme hatası alır → güvenli genişleme.
//
//  İki katman vardır:
//   1. SEMANTİK olaylar (DamageApplied, ParrySucceeded, ...): anlamsal; saf
//      CombatResolver bunları üretebilir, domain de bunlara abone olabilir.
//      Sadece ilkel veri taşır (Flame/ui tipi YOK) → saf test edilebilir.
//   2. SUNUM KOMUTU olayları (*Requested): geçiş dönemi. boss.dart'ın bugün
//      yaptığı tam Sfx/popup/spark/slow-mo çağrısını birebir taşır; presenter
//      bunları aynen yürütür → davranış korunur. Olgunlaşınca çoğu semantik
//      olaylardan türetilebilir.
//
//  NOT: Buradaki `Color`/`Vector2` SALT VERİ taşıyıcısıdır (davranış yok). Saf
//  çekirdek (CombatResolver) bu komut olaylarını ÜRETMEZ; yalnız semantik
//  olayları + karar nesnesini döndürür, dolayısıyla resolver'ın saflığı korunur.
// ============================================================================
import 'dart:ui' show Color;

import 'package:flame/components.dart' show Vector2;

sealed class CombatEvent {
  const CombatEvent();
}

// --- SEMANTİK olaylar (saf; domain + metrik bunlardan beslenir) ------------

/// HP hasarı uygulandı. [toBoss] true ise boss'a, false ise oyuncuya.
class DamageApplied extends CombatEvent {
  final int amount;
  final bool toBoss;
  const DamageApplied(this.amount, {required this.toBoss});
}

/// Boss'un dengesi kırıldı (deathblow penceresi açıldı).
class PostureBroken extends CombatEvent {
  const PostureBroken();
}

/// Parry başarılı. [perfect] = mükemmel (pencerenin ilk dilimi).
class ParrySucceeded extends CombatEvent {
  final bool perfect;
  const ParrySucceeded({required this.perfect});
}

/// Dodge başarılı. [perfect] = i-frame'in erken dilimi.
class DodgeSucceeded extends CombatEvent {
  final bool perfect;
  const DodgeSucceeded({required this.perfect});
}

/// İnfaz (deathblow) çözüldü. [lethal] = öldürücü vuruş.
class Deathblow extends CombatEvent {
  final bool lethal;
  const Deathblow({required this.lethal});
}

/// Faz eşiği geçildi.
class PhaseChanged extends CombatEvent {
  final int phase;
  const PhaseChanged(this.phase);
}

/// Boss yenildi.
class BossDefeated extends CombatEvent {
  final String bossId;
  const BossDefeated(this.bossId);
}

/// Semantik olaysız metrik sayaçları (feint/greed/guard-break) için.
enum MetricKind { feintBaited, greedPunished, guardBreakPunished }

class MetricRecorded extends CombatEvent {
  final MetricKind kind;
  final int amount;
  const MetricRecorded(this.kind, {this.amount = 1});
}

// --- SUNUM KOMUTU olayları (geçiş dönemi; presenter aynen yürütür) ---------

/// Ses kuyruğu. boss.dart'taki tüm `Sfx.*` çağrılarının karşılığı.
enum SfxCue {
  hit,
  postureBreak,
  swordDrop,
  phaseShift,
  whiff,
  deathblow,
  parryPerfect,
  parryLate,
  dodge,
  heavyHit,
  parry,
  block,
}

class SfxRequested extends CombatEvent {
  final SfxCue cue;
  const SfxRequested(this.cue);
}

/// `game.spawnPopup(...)` karşılığı. [color] null ise sunum varsayılanı uygulanır.
class PopupRequested extends CombatEvent {
  final Vector2 position;
  final String text;
  final Color? color;
  final double fontSize;
  final double rise;
  const PopupRequested(
    this.position,
    this.text, {
    this.color,
    this.fontSize = 19,
    this.rise = 34,
  });
}

/// `game.add(ComboText(...))` karşılığı.
class ComboTextRequested extends CombatEvent {
  final Vector2 position;
  final String text;
  const ComboTextRequested(this.position, this.text);
}

/// `game.spawnSpark(...)` karşılığı.
class SparkRequested extends CombatEvent {
  final Vector2 position;
  final Color color;
  const SparkRequested(this.position, this.color);
}

/// `game.spawnPostureBreak(...)` karşılığı. [color] null ise sunum varsayılanı.
class PostureBreakFxRequested extends CombatEvent {
  final Vector2 position;
  final Color? color;
  final double scale;
  const PostureBreakFxRequested(this.position, {this.color, this.scale = 1});
}

/// `game.spawnVignette(...)` karşılığı. Null alanlara sunum varsayılanı uygulanır.
class VignetteRequested extends CombatEvent {
  final Color? color;
  final double? maxLife;
  final int? peakAlpha;
  const VignetteRequested({this.color, this.maxLife, this.peakAlpha});
}

/// `game.requestHitstop(...)` karşılığı.
class HitstopRequested extends CombatEvent {
  final double seconds;
  const HitstopRequested(this.seconds);
}

/// `game.requestSlowmo(...)` karşılığı.
class SlowmoRequested extends CombatEvent {
  final double duration;
  final double scale;
  const SlowmoRequested(this.duration, this.scale);
}

/// `game.requestShake(...)` karşılığı.
class ShakeRequested extends CombatEvent {
  final double amplitude;
  final double duration;
  const ShakeRequested(this.amplitude, this.duration);
}
