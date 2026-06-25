// ============================================================================
//  Rng — seedlenebilir tek rastgelelik kaynağı (Faz G)
// ----------------------------------------------------------------------------
//  architecture.md §16 ilke 9: seedli rastgelelik → deterministik test. Zar
//  (DiceService) bu kaynağı kullanır; ileride boss AI de aynı kaynağa bağlanabilir.
//  Saf Dart — Flame/Flutter bağımlılığı YOK.
// ============================================================================

import 'dart:math';

class Rng {
  Rng([int? seed]) : _r = Random(seed);

  /// Test/replay için sabit seed.
  Rng.seeded(int seed) : _r = Random(seed);

  final Random _r;

  /// [0, max) aralığında tam sayı.
  int nextInt(int max) => _r.nextInt(max);

  /// [0, 1) aralığında ondalık.
  double nextDouble() => _r.nextDouble();

  /// Tek bir zar: 1..sides (dahil).
  int rollDie(int sides) => _r.nextInt(sides) + 1;
}
