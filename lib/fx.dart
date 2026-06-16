// ============================================================================
//  FX  —  Popup + ComboText (orijinal main.dart'tan birebir taşındı)
// ----------------------------------------------------------------------------
//  Hem boss.dart hem game.dart bu dosyayı kullanır (game.spawnPopup → Popup,
//  boss çift-parry → ComboText). Görsel davranış orijinalle aynıdır.
// ============================================================================

import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'game.dart';
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
  double _life;
  final Color color;
  final double ringScale; // deathblow için daha büyük halka (1.0 = normal)

  PostureBreakFx(Vector2 pos, {this.color = kBarBlue, this.ringScale = 1.0})
    : _life = _maxLife * (ringScale > 1 ? 1.25 : 1.0),
      super(position: pos.clone(), anchor: Anchor.center, priority: 98);

  double get _life0 => _maxLife * (ringScale > 1 ? 1.25 : 1.0);

  @override
  void update(double dt) {
    _life -= dt;
    if (_life <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_life / _life0).clamp(0.0, 1.0);
    final r = (14 + (1 - t) * 64) * ringScale;
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..color = color.withAlpha((t * 200).toInt())
        ..style = PaintingStyle.stroke
        ..strokeWidth = (3 + t * 3) * ringScale,
    );
    canvas.drawCircle(
      Offset.zero,
      r * 0.6,
      Paint()
        ..color = kWhite.withAlpha((t * 120).toInt())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * ringScale,
    );
  }
}

// ============================================================================
//  RED VIGNETTE FX  —  arenanın kenarlarını kısaca kırmızıya boyayan sinematik
//  vinyet (deathblow / faz geçişi doruk anı). Kısa ve muhafazakâr alfa →
//  okunabilirliği bozmaz; arena dikdörtgenine kırpılır (HUD'a taşmaz) (06/11).
// ============================================================================
class RedVignetteFx extends PositionComponent
    with HasGameReference<BossArenaGame> {
  final Color color;
  final double maxLife;
  final int peakAlpha;
  double _life;

  RedVignetteFx({
    this.color = const Color(0xFFC0271E),
    this.maxLife = 0.6,
    this.peakAlpha = 92,
  }) : _life = maxLife,
       super(priority: 50);

  @override
  void update(double dt) {
    _life -= dt;
    if (_life <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final r = game.arenaRect;
    if (r.isEmpty) return;
    final age = maxLife - _life;
    // Zarf: hızlı giriş (ilk %20), sonra yumuşak sönüm.
    final env = age < maxLife * 0.2
        ? (age / (maxLife * 0.2)).clamp(0.0, 1.0)
        : (_life / (maxLife * 0.8)).clamp(0.0, 1.0);
    final a = (peakAlpha * env).clamp(0.0, 255.0).toInt();
    if (a <= 0) return;
    final shader = RadialGradient(
      colors: [color.withAlpha(0), color.withAlpha(a)],
      stops: const [0.42, 1.0],
      radius: 0.85,
    ).createShader(r);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)));
    canvas.drawRect(r, Paint()..shader = shader);
    canvas.restore();
  }
}
