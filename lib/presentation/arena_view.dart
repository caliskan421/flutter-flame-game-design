import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'package:boss_parry_arena/app/game/boss_arena_game.dart';
import 'package:boss_parry_arena/presentation/theme.dart';

class ArenaBackground extends PositionComponent
    with HasGameReference<BossArenaGame> {
  ArenaBackground() : super(priority: -11);

  final List<Sprite> _layers = [];

  @override
  Future<void> onLoad() async {
    for (final f in const ['bg/m8_1.png', 'bg/m8_2.png', 'bg/m8_3.png']) {
      _layers.add(await Sprite.load(f));
    }
  }

  @override
  void render(Canvas canvas) {
    final r = game.arenaRect;
    if (r.isEmpty || _layers.isEmpty) return;

    final imgW = _layers.first.srcSize.x;
    final imgH = _layers.first.srcSize.y;
    final scale = max(r.width / imgW, r.height / imgH);
    final dw = imgW * scale, dh = imgH * scale;
    final dx = r.left + (r.width - dw) / 2;
    final dy = r.top + (r.height - dh) / 2;

    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)));
    for (final s in _layers) {
      s.render(canvas, position: Vector2(dx, dy), size: Vector2(dw, dh));
    }
    canvas.restore();
  }
}

class ArenaFrame extends PositionComponent
    with HasGameReference<BossArenaGame> {
  ArenaFrame() : super(priority: -10);

  @override
  void render(Canvas canvas) {
    final r = game.arenaRect;
    if (r.isEmpty) return;

    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(4)),
      Paint()
        ..color = kBlack
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final corner = Paint()
      ..color = kBlack
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    const double t = 22, p = 10;
    canvas.drawLine(
      Offset(r.left + p, r.top + p),
      Offset(r.left + p + t, r.top + p),
      corner,
    );
    canvas.drawLine(
      Offset(r.left + p, r.top + p),
      Offset(r.left + p, r.top + p + t),
      corner,
    );
    canvas.drawLine(
      Offset(r.right - p, r.top + p),
      Offset(r.right - p - t, r.top + p),
      corner,
    );
    canvas.drawLine(
      Offset(r.right - p, r.top + p),
      Offset(r.right - p, r.top + p + t),
      corner,
    );
    canvas.drawLine(
      Offset(r.left + p, r.bottom - p),
      Offset(r.left + p + t, r.bottom - p),
      corner,
    );
    canvas.drawLine(
      Offset(r.left + p, r.bottom - p),
      Offset(r.left + p, r.bottom - p - t),
      corner,
    );
    canvas.drawLine(
      Offset(r.right - p, r.bottom - p),
      Offset(r.right - p - t, r.bottom - p),
      corner,
    );
    canvas.drawLine(
      Offset(r.right - p, r.bottom - p),
      Offset(r.right - p, r.bottom - p - t),
      corner,
    );

    canvas.drawLine(
      Offset(r.left + 40, game.groundY),
      Offset(r.right - 40, game.groundY),
      Paint()
        ..color = kHair
        ..strokeWidth = 1.5,
    );
  }
}
