// ============================================================================
//  HITBOX MODEL  —  ayağa-normalize temas kutusu (saf kural)
// ----------------------------------------------------------------------------
//  KATMAN: combat/rules. SAF Dart — Flame/game.dart/Sfx/sprite çağırmaz, ham
//  sprite pikseline BAĞLANMAZ. Tek-yön bağımlılık korunur (00_INDEX §3.5).
//
//  KOORDİNAT STANDARDI (architecture.md §7.4) — "AYAĞA NORMALİZE":
//  Koordinatlar actor'ün AYAK noktasına göre ve actor BOYUNA oranlanmıştır
//  (birimsiz, ~0..1). Ham sprite pikseli ya da ekran pikseli DEĞİLDİR; böylece
//  hücre boyutu (cellPx) / sheet çözünürlüğü değişse de hitbox sabit kalır.
//
//    origin (0,0) = actor'ün ayağının yere bastığı nokta, gövde ekseninde.
//    +x  = actor'ün BAKTIĞI yön (ileri/erim). Sola bakarken çizimde aynalanır;
//          model yön-bağımsız tutulur, aynalama sunum tarafının işidir.
//    +y  = YUKARI (ayaktan başa). y=1.0 ≈ bir actor boyu.
//    width/height = actor boyunun kesri (0..1).
//
//  Örnek okunuş: x=0.20, y=0.55 → ayaktan yarım boy yukarıda, gövdenin biraz
//  önünde; width=0.60, height=0.25 → öne uzanan yatay bir kılıç erimi.
//
//  ÖNEMLİ: HitboxSpec mekanik temas KARARINI vermez (o `active` penceresi +
//  CombatResolver'ın işi). Bu model "nerede" sorusunu standart bir uzayda
//  belgeler; mekanik otorite asset'e göre yeniden yazılmaz (FAZ_D §14 kuralı).
// ============================================================================

/// Ayağa-normalize bir temas/erim kutusu. Tüm alanlar birimsiz (actor boyuna
/// oranlı); origin actor ayağı, +x bakış yönü, +y yukarı.
class HitboxSpec {
  /// Kutu merkezinin yatay konumu (ayak ekseninden, +x ileri).
  final double x;

  /// Kutu merkezinin dikey konumu (yerden yukarı; +y yukarı).
  final double y;

  /// Genişlik (actor boyunun kesri).
  final double width;

  /// Yükseklik (actor boyunun kesri).
  final double height;

  const HitboxSpec({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  double get left => x - width / 2;
  double get right => x + width / 2;
  double get bottom => y - height / 2;
  double get top => y + height / 2;
}

/// knight_1.attack2 (ağır, öne taahhütlü savruluş) için ÖRNEK hitbox —
/// ayağa-normalize standardın referans örneği (FAZ_D §5 kabul kriteri).
/// Erim önde (x>0), gövde-bel yüksekliğinde, geniş ama orta-ince bir kesik.
const HitboxSpec kKnight1Attack2Hitbox = HitboxSpec(
  x: 0.28,
  y: 0.55,
  width: 0.62,
  height: 0.26,
);
