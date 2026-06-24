import 'dart:ui' show Image;

import 'package:flame/components.dart';

import 'characters.dart';
import 'presentation/animation_binding.dart';

typedef SpriteImageLoader = Future<Image> Function(String path);

enum AttackPhase { windup, active, recover }

/// SAF: faz + ilerleme + (opsiyonel) `contactFrame` pivot'undan kare indeksi.
///
/// Mekanik OTORİTE süreyi belirler (çağıran `phase` + `progress` verir); bu
/// fonksiyon yalnız ASSET'in hangi karesini göstereceğini hesaplar.
/// [contactFrame] null ise eski davranış (`mid = (n/2).floor()`) BİREBİR korunur
/// — binding'siz/marker'sız karakterler için FALLBACK budur. contact verildiğinde
/// pivot ona kayar: windup [0..pivot-1], active = pivot, recover [pivot+1..n-1].
/// knight_1'de contact == mid olduğundan görsel çıktı değişmez.
int attackFrameIndex({
  required int n,
  required AttackPhase phase,
  required double progress,
  int? contactFrame,
}) {
  if (n <= 0) return 0;
  final mid = (n / 2).floor().clamp(0, n - 1);
  final pivot = (contactFrame ?? mid).clamp(0, n - 1);
  final p = progress.clamp(0.0, 1.0);
  switch (phase) {
    case AttackPhase.windup:
      final span = pivot;
      return span <= 0 ? 0 : (p * span).floor().clamp(0, span - 1);
    case AttackPhase.active:
      return pivot;
    case AttackPhase.recover:
      final start = (pivot + 1).clamp(0, n - 1);
      final span = n - start;
      return span <= 0 ? n - 1 : (start + p * span).floor().clamp(start, n - 1);
  }
}

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

  /// Saldırı karesi. [binding] verilirse `markerFrames['contact']` DARBE karesini
  /// (active fazda gösterilen kare) belirler; yoksa eski `mid = n/2` davranışına
  /// düşer (geriye uyumlu). Mekanik temas yine `active` penceresinden gelir.
  Sprite attackFrame(
    String key,
    double remaining,
    double duration, {
    required AttackPhase phase,
    AnimationBinding? binding,
  }) {
    final list = frames(key);
    final p = (1 - (remaining / duration)).clamp(0.0, 1.0);
    // Binding yalnız KENDİ sheet'ine uygulanır (yanlış id → güvenli fallback).
    final contact = contactFrameFor(binding, key);
    assert(
      contact == null || (contact >= 0 && contact < list.length),
      'AnimationBinding contact=$contact "$key" (${list.length} kare) '
      'sınırları dışında',
    );
    final idx = attackFrameIndex(
      n: list.length,
      phase: phase,
      progress: p,
      contactFrame: contact,
    );
    return list[idx];
  }
}
