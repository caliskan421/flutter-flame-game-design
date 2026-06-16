import 'dart:ui' show Image;

import 'package:flame/components.dart';

import 'characters.dart';

typedef SpriteImageLoader = Future<Image> Function(String path);

enum AttackPhase { windup, active, recover }

class SpriteStripBank {
  SpriteStripBank(this.def);

  final CharacterDef def;
  final Map<String, List<Sprite>> _frames = {};

  bool get isLoaded => _frames.isNotEmpty;

  Future<void> load(SpriteImageLoader loadImage) async {
    for (final entry in def.sheets.entries) {
      final key = entry.key;
      final spec = entry.value;
      final image = await loadImage(charSheetPath(def, key));
      final cell = spec.cellH;
      _frames[key] = [
        for (int i = 0; i < spec.frames; i++)
          Sprite(
            image,
            srcPosition: Vector2(i * cell, 0),
            srcSize: Vector2(cell, cell),
          ),
      ];
    }
  }

  List<Sprite> frames(String key, {String fallback = 'idle'}) {
    final list = _frames[key] ?? _frames[fallback];
    if (list == null || list.isEmpty) {
      throw StateError('Sprite strip "$key" is not loaded for ${def.id}.');
    }
    return list;
  }

  Sprite? firstOrNull(String key) {
    final list = _frames[key];
    return list == null || list.isEmpty ? null : list.first;
  }

  Sprite loop(String key, double elapsed, double step) {
    final list = frames(key);
    return list[(elapsed / step).floor() % list.length];
  }

  Sprite once(String key, double remaining, double duration) {
    final list = frames(key);
    final p = (1 - (remaining / duration)).clamp(0.0, 1.0);
    return list[(p * list.length).floor().clamp(0, list.length - 1)];
  }

  Sprite hold(String key, double remaining, double duration) {
    final list = frames(key);
    final p = (1 - (remaining / duration)).clamp(0.0, 1.0);
    return list[(p * (list.length - 1)).round().clamp(0, list.length - 1)];
  }

  Sprite deathFrame(double elapsed, double frameTime) {
    final list = frames('dead');
    final i = (elapsed / frameTime).floor().clamp(0, list.length - 1);
    return list[i];
  }

  Sprite attackFrame(
    String key,
    double remaining,
    double duration, {
    required AttackPhase phase,
  }) {
    final list = frames(key);
    final n = list.length;
    final mid = (n / 2).floor().clamp(0, n - 1);
    final p = (1 - (remaining / duration)).clamp(0.0, 1.0);

    final int idx;
    switch (phase) {
      case AttackPhase.windup:
        final span = mid;
        idx = span <= 0 ? 0 : (p * span).floor().clamp(0, span - 1);
        break;
      case AttackPhase.active:
        idx = mid;
        break;
      case AttackPhase.recover:
        final start = (mid + 1).clamp(0, n - 1);
        final span = n - start;
        idx = span <= 0
            ? n - 1
            : (start + p * span).floor().clamp(start, n - 1);
        break;
    }
    return list[idx];
  }
}
