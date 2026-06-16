// ============================================================================
//  PROJECTILE  —  menzilli boss'ların fırlattığı uçan görsel mermi
// ----------------------------------------------------------------------------
//  Boss → oyuncu arasında DÜZ bir çizgide ilerler. Hedefe ulaşınca bir KEZ
//  onArrive(self) çağrılır (temas/parry çözümü Boss tarafında yapılır).
//  Parry başarılıysa Boss self.deflect() der: mermi geri savrulup ~0.5s'de
//  sönerek kaldırılır. Sprite kareleri içeride döngüyle canlandırılır.
// ============================================================================

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'game.dart';

class Projectile extends PositionComponent
    with HasGameReference<BossArenaGame> {
  final Sprite Function() frame; // boss güncel mermi karesini sağlar
  final void Function(Projectile self) onArrive; // hedefe varınca BİR KEZ

  final Vector2 _from;
  Vector2 _target;
  final double speed;

  Vector2 _heading = Vector2.zero();
  bool _arrived = false;
  bool _deflected = false;

  // Saptırma sonrası geri uçuş + sönme
  double _fade = 1.0;
  double _deflectT = 0;
  static const double _deflectLife = 0.5;

  static const double _drawSize = 64;

  Projectile(
    Vector2 from,
    Vector2 to,
    this.speed, {
    required this.frame,
    required this.onArrive,
  }) : _from = from.clone(),
       _target = to.clone(),
       super(
         position: from.clone(),
         size: Vector2.all(_drawSize),
         anchor: Anchor.center,
         priority: 50,
       ) {
    final dir = (_target - _from);
    if (dir.length > 0) _heading = dir.normalized();
  }

  bool get arrived => _arrived;
  bool get deflected => _deflected;

  // Saptır: yönü ters çevir (kökene doğru uç), sonra ~0.5s içinde sön ve kaldır.
  void deflect() {
    if (_deflected) return;
    _deflected = true;
    _arrived = true; // artık temas çözülmez
    _heading = -_heading;
    _target = _from.clone();
    _deflectT = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_deflected) {
      // Geri uçuş + sönme
      position += _heading * speed * dt;
      _deflectT += dt;
      _fade = (1 - _deflectT / _deflectLife).clamp(0.0, 1.0);
      if (_deflectT >= _deflectLife) removeFromParent();
      return;
    }

    // Düz çizgide hedefe ilerle
    final remaining = _target - position;
    final dist = remaining.length;
    final step = speed * dt;

    if (!_arrived && (dist <= step || dist < 1)) {
      position = _target.clone();
      _arrived = true;
      onArrive(this); // BİR KEZ — Boss temas/parry çözer (deflect veya kaldır)
      return;
    }

    if (!_arrived) {
      position += _heading * step;
    }
  }

  @override
  void render(Canvas canvas) {
    final sprite = frame();
    final a = (_fade.clamp(0.0, 1.0) * 255).toInt();
    final paint = Paint()..color = const Color(0xFFFFFFFF).withAlpha(a);
    // Hareket yönüne göre yatay aynalama (geri saptırınca ters baksın).
    final mirror = _heading.x < 0;
    canvas.save();
    if (mirror) {
      canvas.translate(size.x, 0);
      canvas.scale(-1, 1);
    }
    sprite.render(
      canvas,
      position: Vector2.zero(),
      size: size,
      overridePaint: paint,
    );
    canvas.restore();
  }
}
