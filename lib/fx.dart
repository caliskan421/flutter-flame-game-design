// ============================================================================
//  FX  —  Popup + ComboText (orijinal main.dart'tan birebir taşındı)
// ----------------------------------------------------------------------------
//  Hem boss.dart hem game.dart bu dosyayı kullanır (game.spawnPopup → Popup,
//  boss çift-parry → ComboText). Görsel davranış orijinalle aynıdır.
// ============================================================================

import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

// ============================================================================
//  POPUP  —  pop-in + yükselip sönen hasar/puan yazısı
// ============================================================================
class Popup extends PositionComponent {
  final String text;
  final Color color;
  final double fontSize;
  final double rise;
  final double maxLife;
  double _life;

  Popup(
    Vector2 pos,
    this.text, {
    this.color = kBlack,
    this.fontSize = 19,
    this.rise = 34,
    this.maxLife = 0.78,
  }) : _life = maxLife,
       super(position: pos.clone(), anchor: Anchor.center, priority: 95);

  @override
  void update(double dt) {
    _life -= dt;
    position.y -= rise * dt;
    if (_life <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_life / maxLife).clamp(0.0, 1.0);
    final age = maxLife - _life;
    final sc = age < 0.12 ? easeOutBack((age / 0.12).clamp(0, 1)) : 1.0;
    final tp = TextPaint(
      style: TextStyle(
        color: color.withAlpha((t * 255).toInt()),
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
      ),
    );
    final m = tp.getLineMetrics(text);
    canvas.save();
    canvas.scale(sc, sc);
    tp.render(canvas, text, Vector2(-m.width / 2, -fontSize / 2));
    canvas.restore();
  }
}

// ============================================================================
//  COMBO TEXT  —  overshoot ile büyüyen estetik "×2 KOMBO" yazısı
// ============================================================================
class ComboText extends PositionComponent {
  final String text;
  static const double _maxLife = 1.05;
  double _life = _maxLife;

  ComboText(Vector2 pos, this.text)
    : super(position: pos.clone(), anchor: Anchor.center, priority: 96);

  @override
  void update(double dt) {
    _life -= dt;
    position.y -= 14 * dt; // yavaşça yüksel
    if (_life <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final age = _maxLife - _life;
    // Pose-to-pose: 0->overshoot->settle, sonda fade + hafif büyüme
    double sc;
    if (age < 0.20) {
      sc = easeOutBack((age / 0.20).clamp(0, 1)) * 1.18;
    } else if (_life < 0.30) {
      sc = 1.18 + (1 - _life / 0.30) * 0.18;
    } else {
      sc = 1.18;
    }
    final alpha = _life < 0.30 ? (_life / 0.30).clamp(0.0, 1.0) : 1.0;
    final a = (alpha * 255).toInt();

    final tp = TextPaint(
      style: TextStyle(
        color: kBlack.withAlpha(a),
        fontSize: 30,
        fontWeight: FontWeight.w900,
        letterSpacing: 3,
      ),
    );
    final m = tp.getLineMetrics(text);

    canvas.save();
    canvas.scale(sc, sc);
    // altına ince vurgu çizgisi (staging/appeal)
    final lineW = m.width * 0.9;
    canvas.drawRect(
      Rect.fromLTWH(-lineW / 2, fontSizeHalf + 4, lineW, 2.5),
      Paint()..color = kBlack.withAlpha(a),
    );
    tp.render(canvas, text, Vector2(-m.width / 2, -fontSizeHalf));
    canvas.restore();
  }

  double get fontSizeHalf => 15;
}

// ============================================================================
//  SPARK  —  temas anı kıvılcımı (parry/posture chip). Kısa ışın demeti.
// ============================================================================
class Spark extends PositionComponent {
  final Color color;
  static const double _maxLife = 0.26;
  double _life = _maxLife;
  final List<double> _angles;

  Spark(Vector2 pos, this.color)
    : _angles = List.generate(7, (i) => (i / 7) * pi * 2 + Random().nextDouble() * 0.4),
      super(position: pos.clone(), anchor: Anchor.center, priority: 97);

  @override
  void update(double dt) {
    _life -= dt;
    if (_life <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_life / _maxLife).clamp(0.0, 1.0);
    final reach = 6 + (1 - t) * 20;
    final paint = Paint()
      ..color = color.withAlpha((t * 230).toInt())
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    for (final a in _angles) {
      final inner = Offset(cos(a) * 4, sin(a) * 4);
      final outer = Offset(cos(a) * reach, sin(a) * reach);
      canvas.drawLine(inner, outer, paint);
    }
  }
}

// ============================================================================
//  POSTURE BREAK FX  —  denge kırılınca genişleyip sönen şok halkası.
// ============================================================================
class PostureBreakFx extends PositionComponent {
  static const double _maxLife = 0.5;
  double _life = _maxLife;

  PostureBreakFx(Vector2 pos)
    : super(position: pos.clone(), anchor: Anchor.center, priority: 98);

  @override
  void update(double dt) {
    _life -= dt;
    if (_life <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_life / _maxLife).clamp(0.0, 1.0);
    final r = 14 + (1 - t) * 64;
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..color = kBarBlue.withAlpha((t * 200).toInt())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 + t * 3,
    );
    canvas.drawCircle(
      Offset.zero,
      r * 0.6,
      Paint()
        ..color = kWhite.withAlpha((t * 120).toInt())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}
