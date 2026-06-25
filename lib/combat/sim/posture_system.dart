// ============================================================================
//  PostureSystem — boss dengesi (posture) için SAF durum & kurallar
// ----------------------------------------------------------------------------
//  Faz F (boss.dart ayrıştırma): denge değeri, yumuşatılmış HUD değeri, regen
//  gecikmesi ve hasar/kırılma KARARI burada toplanır. Flame/Sfx/event YOK —
//  saf Dart, Flame olmadan unit test edilebilir (architecture.md §9).
//
//  Davranış-koruyan: tüm sayılar boss.dart'tan birebir taşındı. Kırılma anının
//  EFEKTLERİ ve `staggered` state geçişi boss.dart'ta kalır; bu sistem yalnız
//  "bu hasar dengeyi kırdı mı?" kararını döndürür (tek-yön bağımlılık).
// ============================================================================

class PostureSystem {
  PostureSystem(this.max);

  /// Maksimum denge (CharacterDef.maxPosture).
  final int max;

  /// Anlık denge (0..max).
  late double value = max.toDouble();

  /// HUD'da gösterilen yumuşatılmış denge.
  late double display = max.toDouble();

  /// Son denge hasarından bu yana geçen süre (regen gecikmesi için).
  double _idle = 0;

  /// Saniyede regen miktarı.
  static const double regenPerSecond = 8;

  /// Regen başlamadan önceki sessiz pencere (s).
  static const double regenDelay = 1.1;

  /// Maç/sıfırlama: tam denge, gecikme temiz.
  void reset() {
    value = max.toDouble();
    display = max.toDouble();
    _idle = 0;
  }

  /// Dengeyi tepeye sabitle (test guard / faz geçişi / infaz sonrası segment).
  void forceFull() {
    value = max.toDouble();
  }

  /// Denge hasarı uygula. Bu hasar dengeyi KIRDIYSA `true` döner (çağıran
  /// `breakPosture` efektlerini ve `staggered` geçişini yapar).
  /// [staggered] zaten kırık durumda yeniden kırma olmaz (birebir eski koşul).
  bool applyDamage(int dmg, {required bool dying, required bool staggered}) {
    if (dmg <= 0 || dying) return false;
    value = (value - dmg).clamp(0, max).toDouble();
    _idle = 0;
    return value <= 0 && !staggered;
  }

  /// Kırılma anında denge sıfırlanır (efektler boss.dart'ta).
  void onBroken() {
    value = 0;
  }

  /// HUD değerini gerçek değere doğru yumuşat (her frame; eski dt*9 katsayısı).
  void tickDisplay(double dt) {
    display += (value - display) * (dt * 9).clamp(0, 1);
  }

  /// Denge rejenerasyonu: stagger DIŞINDA, kısa gecikmeden sonra. Yalnız oyun
  /// oynanırken çağrılır (eski `update` davranışı).
  void tickRegen(double dt, {required bool staggered}) {
    _idle += dt;
    if (!staggered && _idle > regenDelay && value < max) {
      value = (value + regenPerSecond * dt).clamp(0, max).toDouble();
    }
  }
}
