// ============================================================================
//  BossView — Boss'un GÖRSEL sunumu (sprite seçimi + telegraf + açık-işareti)
// ----------------------------------------------------------------------------
//  Faz F (boss.dart ayrıştırma): tüm Canvas/Flame çizimi buraya taşındı. View
//  yalnız Boss'un durumunu OKUR (presentation → sim, tek yön) ve çizer; oyun
//  durumunu DEĞİŞTİRMEZ. Davranış-koruyan: çizim mantığı boss.dart'tan birebir
//  taşındı (yalnızca alan erişimleri `_boss.` getter'larına çevrildi).
// ============================================================================

import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../boss.dart';
import '../characters.dart';
import '../sprite_strip.dart';
import '../theme.dart';
import 'animation_binding.dart';

// mikiri/thrust telegrafı (kırmızıdan ayrı) — sunum rengi.
const Color _kThrust = Color(0xFF9B5DE5);

class BossView {
  BossView(this._boss);

  final Boss _boss;

  void render(Canvas canvas) {
    if (!_boss.sprites.isLoaded) return;

    final sprite = _frameFor();
    final s = _boss.def.cellPx;
    final left = _boss.size.x / 2 - s / 2;
    final top = _boss.size.y - _boss.def.feetV * s;

    final mirror = _boss.game.player.position.x < _boss.position.x;
    canvas.save();
    if (mirror) {
      canvas.translate(_boss.size.x, 0);
      canvas.scale(-1, 1);
    }
    sprite.render(canvas, position: Vector2(left, top), size: Vector2(s, s));
    canvas.restore();

    _renderTelegraph(canvas);
    _renderOpenMarker(canvas);
  }

  Sprite _frameFor() {
    final sprites = _boss.sprites;
    if (_boss.dying) {
      return sprites.deathFrame(_boss.deathT, _boss.deathFrameTime);
    }
    switch (_boss.state) {
      case BossState.idle:
      case BossState.gap:
        return sprites.loop('idle', _boss.t, 0.10);
      case BossState.guard:
        return sprites.frames('defend').last;
      case BossState.approach:
        if (_boss.game.actionSystem.bossUsesIdleApproachSprite) {
          return sprites.loop('idle', _boss.t, 0.10);
        }
        return sprites.loop('walk', _boss.t, 0.09);
      case BossState.reposition:
        return sprites.loop('walk', _boss.t, 0.09);
      case BossState.retreat:
        return sprites.loop('run', _boss.t, 0.07);
      case BossState.offBalance:
      case BossState.staggered:
        return sprites.loop('hurt', _boss.t, 0.12);
      case BossState.phaseTransition:
        if (_boss.phaseTransitionHurtHold > 0) {
          return sprites.loop('hurt', _boss.t, 0.12);
        }
        // Dirilme/poz alma: savunma duruşunu tut (kısa staging).
        return sprites.frames('defend').last;
      case BossState.windup:
        final beat = _boss.currentBeat!;
        return sprites.attackFrame(
          beat.animKey,
          _boss.timer,
          beat.windup,
          phase: AttackPhase.windup,
          binding: resolveAnimationBinding(beat.animationBindingId),
        );
      case BossState.active:
        if (_boss.hurtT > 0) return sprites.loop('hurt', _boss.t, 0.08);
        final beat = _boss.currentBeat!;
        return sprites.attackFrame(
          beat.animKey,
          _boss.timer,
          beat.active,
          phase: AttackPhase.active,
          binding: resolveAnimationBinding(beat.animationBindingId),
        );
      case BossState.recover:
        if (_boss.hurtT > 0) return sprites.loop('hurt', _boss.t, 0.08);
        final beat = _boss.currentBeat!;
        return sprites.attackFrame(
          beat.animKey,
          _boss.timer,
          beat.recover,
          phase: AttackPhase.recover,
          binding: resolveAnimationBinding(beat.animationBindingId),
        );
    }
  }

  // TELEGRAF — SADE MODEL: yalnız KIRMIZI (kaçılması gereken) saldırıyı işaretler.
  // Renksiz = parry (varsayılan). Kırmızı görürsen DODGE. Tek istisna budur.
  void _renderTelegraph(Canvas canvas) {
    final state = _boss.state;
    if (state != BossState.windup && state != BossState.active) return;
    final beat = _boss.currentBeat;
    if (beat == null) return;
    final String label;
    final Color color;
    if (beat.defense == DefenseProfile.guardBreak) {
      label = 'KAÇ!  (SHIFT)';
      color = kBarRed;
    } else if (beat.defense == DefenseProfile.thrust) {
      label = 'MİKİRİ!  (SHIFT)';
      color = _kThrust;
    } else if (beat.guardDirection == GuardDirection.high &&
        _boss.game.actionSystem.upArrowParries) {
      label = beat.defense == DefenseProfile.tracking
          ? '↑ SAVUŞTUR'
          : '↑ / SHIFT';
      color = kBarBlue;
    } else if (beat.guardDirection == GuardDirection.low &&
        _boss.game.actionSystem.downArrowParries) {
      label = beat.defense == DefenseProfile.tracking
          ? '↓ SAVUŞTUR'
          : '↓ / SHIFT';
      color = kBarBlue;
    } else if (beat.defense == DefenseProfile.tracking &&
        beat.guardDirection == GuardDirection.any) {
      label = 'SPACE SAVUŞTUR';
      color = kBarBlue;
    } else {
      return;
    }

    final pulse = 0.55 + 0.45 * sin(_boss.t * 18);
    final tp = TextPaint(
      style: TextStyle(
        color: color,
        fontSize: 14,
        fontWeight: FontWeight.w900,
        letterSpacing: 1,
      ),
    );
    final m = tp.getLineMetrics(label);
    // Sprite başı ~ y=-(cellPx - 112). Pili onun da üstüne, net bir bantta koy.
    final double cy = -(_boss.def.cellPx - _boss.size.y) - 22;
    final double pillW = m.width + 22;
    final pill = Rect.fromCenter(
      center: Offset(_boss.size.x / 2, cy),
      width: pillW,
      height: 24,
    );
    final rr = RRect.fromRectAndRadius(pill, const Radius.circular(5));
    canvas.drawRRect(rr, Paint()..color = kWhite.withAlpha(235));
    canvas.drawRRect(
      rr,
      Paint()
        ..color = color.withAlpha((150 + 105 * pulse).toInt())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    tp.render(canvas, label, Vector2(_boss.size.x / 2 - m.width / 2, cy - 7));
  }

  void _renderOpenMarker(Canvas canvas) {
    if (!_boss.isOpen) return;
    // Denge kırık → F çoklu kesik + G infaz; dodge sonrası açık → normal "VUR".
    final bool deathblow = _boss.state == BossState.staggered;
    final pulse = 0.5 + 0.5 * sin(_boss.t * (deathblow ? 22 : 16));
    final infl = (deathblow ? 7 : 5) + pulse * (deathblow ? 7 : 5);
    final Color ring = deathblow ? kBarRed : kBlack;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        _boss.size.toRect().inflate(infl),
        const Radius.circular(10),
      ),
      Paint()
        ..color = ring.withAlpha((150 + 105 * pulse).toInt())
        ..style = PaintingStyle.stroke
        ..strokeWidth = deathblow ? 4 : 3,
    );
    final String label = deathblow ? 'F:15  G:İNFAZ' : 'VUR  F';
    final tp = TextPaint(
      style: TextStyle(
        color: deathblow ? kBarRed : kBarGreen,
        fontSize: deathblow ? 15 : 16,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
      ),
    );
    final m = tp.getLineMetrics(label);
    final double cy = -(_boss.def.cellPx - _boss.size.y) - 22;
    final pill = Rect.fromCenter(
      center: Offset(_boss.size.x / 2, cy),
      width: m.width + 22,
      height: 24,
    );
    final rr = RRect.fromRectAndRadius(pill, const Radius.circular(5));
    canvas.drawRRect(rr, Paint()..color = kWhite.withAlpha(235));
    canvas.drawRRect(
      rr,
      Paint()
        ..color = (deathblow ? kBarRed : kBarGreen).withAlpha(
          (150 + 105 * pulse).toInt(),
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = deathblow ? 3 : 2.5,
    );
    tp.render(canvas, label, Vector2(_boss.size.x / 2 - m.width / 2, cy - 7));
  }

  String get phaseLabelTr {
    if (_boss.dying) return 'Devrildi';
    switch (_boss.state) {
      case BossState.idle:
        return 'Bekliyor';
      case BossState.approach:
        return 'Yaklaşıyor';
      case BossState.windup:
        return 'Hazırlanıyor';
      case BossState.active:
        return 'VURUYOR';
      case BossState.recover:
        return 'Toparlanıyor';
      case BossState.gap:
        return 'Ara';
      case BossState.guard:
        return 'KALKAN';
      case BossState.offBalance:
        return 'AÇIK!';
      case BossState.staggered:
        return 'İNFAZ FIRSATI';
      case BossState.phaseTransition:
        return 'FAZ DEĞİŞİYOR';
      case BossState.reposition:
        return 'Yer değiştiriyor';
      case BossState.retreat:
        return 'Geri çekiliyor';
    }
  }
}
