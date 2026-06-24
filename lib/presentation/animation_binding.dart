// ============================================================================
//  ANIMATION BINDING  —  mekanik ↔ asset kontratı (sunum katmanı)
// ----------------------------------------------------------------------------
//  "Hangi sprite karesi temas/telegraf karesi?" bilgisini KODUN İÇİNDEN çıkarıp
//  VERİYE taşır. Mekanik otorite (`ActionTimeline.active` / `Beat.active`)
//  kalır; binding yalnız ASSET'i anlatır ve onu mekaniğe HİZALAR
//  (architecture.md §7.2, §16 ilke 3).
//
//  KATMAN: presentation. Saf veridir — Flame/Sfx/game.dart/spawnPopup ÇAĞIRMAZ.
//  Sunum yan etkisi gerekiyorsa Faz B'deki EventBus/CombatPresenter yolundan
//  geçirilir (bkz. ActionEventMarker → CombatEvent köprüsü).
//
//  ÖNEMLİ — "asset'e göre mekanik yazmak YASAK": `markerFrames` sürelere
//  KARIŞMAZ; yalnız mevcut mekanik penceresine hizalanmış kareyi işaret eder.
// ============================================================================

/// Bir saldırı animasyonunun (tek sheet) mekaniğe bağlanması.
///
/// [markerFrames]: isimli karelerin sheet içindeki indeksleri. Bilinen adlar:
///   'anticipation' (telegraf öncesi), 'telegraph', 'contact' (DARBE karesi),
///   'recover'. Yalnız 'contact' render'ı etkiler (active fazda gösterilen
///   kare); diğerleri belge/olay (D5) içindir. Eksik marker → render eski
///   davranışa düşer (`SpriteStripBank.attackFrame` içinde `mid = n/2`).
class AnimationBinding {
  final String id;
  final String sheetKey; // CharacterDef.sheets anahtarı (örn. 'attack2')
  final double frameTime; // bilgi amaçlı kare süresi; süre OTORİTESİ değildir
  final Map<String, int> markerFrames;

  const AnimationBinding({
    required this.id,
    required this.sheetKey,
    this.frameTime = 0.08,
    this.markerFrames = const {},
  });

  /// DARBE (temas) karesi — `active` penceresine hizalı. Yoksa null → fallback.
  int? get contactFrame => markerFrames['contact'];

  /// İsimli marker karesi (yoksa null).
  int? markerFrame(String name) => markerFrames[name];
}

// ============================================================================
//  KAYIT (registry)  —  id → binding
// ----------------------------------------------------------------------------
//  Faz D kapsamı: YALNIZ samuray (kPlayerDef) ve knight_1 (kTestOpponent).
//  Tüm roster → kademeli, sonraki iş (FAZ_D §2 HARİÇ).
// ============================================================================

const Map<String, AnimationBinding> kAnimationBindings = {
  // --- knight_1 (kTestOpponent) -------------------------------------------
  // GERÇEKTEN render edilen yol: boss.dart `_frameFor` → attackFrame(binding:).
  // contact == eski `mid = (n/2).floor()` → görsel BİREBİR aynı (regresyon yok):
  //   attack1: 5 kare (mid=2), attack2: 4 kare (mid=2), attack3: 4 kare (mid=2).
  'knight_1.attack1': AnimationBinding(
    id: 'knight_1.attack1',
    sheetKey: 'attack1',
    markerFrames: {'anticipation': 1, 'contact': 2, 'recover': 3},
  ),
  'knight_1.attack2': AnimationBinding(
    id: 'knight_1.attack2',
    sheetKey: 'attack2',
    markerFrames: {'anticipation': 1, 'contact': 2, 'recover': 3},
  ),
  'knight_1.attack3': AnimationBinding(
    id: 'knight_1.attack3',
    sheetKey: 'attack3',
    markerFrames: {'anticipation': 1, 'contact': 2, 'recover': 3},
  ),

  // --- samuray (kPlayerDef) -----------------------------------------------
  // Oyuncu saldırı karesi oyunda `SpriteStripBank.once(...)` ile LİNEER çizilir
  // (player.dart) — kodda örtük bir "temas karesi" YOKTUR, mekanik temas yalnız
  // ActionTimeline.active'den gelir. Bu yüzden bu binding'ler render'ı
  // DEĞİŞTİRMEZ; Faz C'nin yer tutucu animationBindingId'lerini GERÇEK binding'e
  // çözer (VERİ) ve contact karesini active penceresine HİZALI belgeler (D5/
  // HitboxSpec için hazır). 'contact', light/heavy timeline'ının active
  // penceresinde `once`'ın gösterdiği kare aralığına düşer.
  'player.attack.light': AnimationBinding(
    id: 'player.attack.light',
    sheetKey: 'attack1', // light combo attack1/2/3 sheet'lerini gezer; ilk vuruş
    markerFrames: {'contact': 1},
  ),
  'player.attack.heavy': AnimationBinding(
    id: 'player.attack.heavy',
    sheetKey: 'attack1',
    markerFrames: {'contact': 1},
  ),
  'player.parry': AnimationBinding(
    id: 'player.parry',
    sheetKey: 'defend', // parry savunma duruşunu kullanır (saldırı sheet'i yok)
  ),
  'player.dodge': AnimationBinding(
    id: 'player.dodge',
    sheetKey: 'run', // dodge koşu döngüsüyle çizilir
  ),
};

/// [id] → kayıtlı binding (yoksa null → çağıran taraf eski davranışa düşer).
AnimationBinding? resolveAnimationBinding(String? id) =>
    id == null ? null : kAnimationBindings[id];

/// Bir binding YALNIZ kendi [sheetKey]'ine uygulanır: çizilen [sheetKey] ile
/// binding'in sheet'i uyuşmazsa null döner → çağıran eski `mid = n/2` davranışına
/// düşer. Böylece yanlış/eski bir animationBindingId sessiz bir GÖRSEL KAYMAYA
/// değil, güvenli fallback'e çevrilir.
int? contactFrameFor(AnimationBinding? binding, String sheetKey) =>
    (binding != null && binding.sheetKey == sheetKey)
        ? binding.contactFrame
        : null;
