// ============================================================================
//  CHARACTERS  —  data-driven dövüşçü tanımları (6 karakter, 2 sınıf)
// ----------------------------------------------------------------------------
//  Her karakterin kendi sprite tabakası (sheets) ve bir KOMBO HAVUZU (combos)
//  vardır. Boss bu havuzdan ağırlıklı seçim yapıp tek bir durum makinesi sürer.
//
//  REDESIGN (COMBAT_REDESIGN_PHASES): Her beat artık yalnız süre değil, bir
//  SAVUNMA PROFİLİ (DefenseProfile) taşır. Bu profil oyuncunun doğru cevabını
//  belirler: parry'lenir mi, dodge'lanır mı, yanlış araç cezalandırılır mı.
//  Ayrıca posture hasarı (parry → boss dengesi) ve punishOnDodge (dodge →
//  açılış) verisi beat üstündedir.
// ============================================================================

enum CharClass { knight, wizard }

/// Görsel/animasyon ve hasar kategorisi (sprite seçimi + chip ikonu için).
enum BeatKind { meleeLight, meleeHeavy, ranged, feint }

/// SAVUNMA PROFİLİ — oyuncunun bu beat'e vermesi gereken doğru cevap.
///   normal      → parry VEYA dodge işe yarar.
///   heavy       → dodge edilirse PUNISH açılır; parry posture'a çok yarar ama riskli.
///   guardBreak  → parry/blok CEZALANDIRIR; dodge etmelisin.
///   tracking    → dodge'u YAKALAR (ceza); parry etmelisin.
///   thrust      → MİKİRİ: delici saldırı; dodge (ileri-bas) ile bastırılır,
///                 parry cezalanır. Dodge edilince boss büyük açık verir.
///   delayed     → uzun/değişken windup; erken basışı cezalandırır.
///   feint       → aldatma; erken savunmayı boşa düşürür, hasar vermez.
///   ranged      → parry ile yansır (posture); dodge ile sadece kurtulursun.
enum DefenseProfile {
  normal,
  heavy,
  guardBreak,
  tracking,
  thrust,
  delayed,
  feint,
  ranged,
}

enum GuardDirection { any, high, low }

/// Bir kombo içindeki TEK bir vuruş (beat). Boss bu veriye göre windup→active→
/// recover fazlarını sürer; SPACE penceresi preWindow/grace ile çözülür.
class Beat {
  final BeatKind kind;
  final DefenseProfile defense;
  final String animKey; // melee için gövde anim; ranged için cast anim
  final double windup, active, recover, gapAfter;
  final double preWindow, grace; // SPACE temas ÖNCESİ preWindow, SONRASI grace
  // DODGE penceresi: parry'den DAHA GENİŞ ve daha affedici.
  final double dodgePre;
  final int damage; // savunulmazsa oyuncuya verilen HP hasarı
  final int postureDamage; // başarılı parry'nin boss DENGESİNE verdiği hasar
  final GuardDirection guardDirection; // testte üst/alt savuşturma ayrımı
  // Bu beat'i dodge etmek boss'ta bir PUNISH penceresi (offBalance) açar mı?
  // Yalnız ağır/committed saldırılar için true; hafiflerde dodge sadece sıyrılma.
  final bool punishOnDodge;
  final bool mustDefend; // sidebar'da ZORUNLU olarak vurgulanır
  final String? projectileKey; // null değilse => ranged; mermi sheet anahtarı
  final double projectileSpeed; // px/s
  // Faz D: bu beat'in saldırı sheet'ini mekaniğe bağlayan AnimationBinding id'si
  // (presentation/animation_binding.dart kaydında çözülür). null → sprite_strip
  // eski `mid = n/2` davranışına düşer (geriye uyumlu fallback).
  final String? animationBindingId;

  const Beat({
    required this.kind,
    this.defense = DefenseProfile.normal,
    required this.animKey,
    this.windup = 0.4,
    this.active = 0.15,
    this.recover = 0.3,
    this.gapAfter = 0.3,
    this.preWindow = 0.13,
    this.grace = 0.06,
    this.dodgePre = 0.22,
    this.damage = 12,
    this.postureDamage = 16,
    this.guardDirection = GuardDirection.any,
    this.punishOnDodge = false,
    this.mustDefend = false,
    this.projectileKey,
    this.projectileSpeed = 620,
    this.animationBindingId,
  });

  bool get isRanged => projectileKey != null;

  /// Kombo-İÇİ ADAPTASYON (09): boss çalışırken bir beat'i oyuncu eğilimine göre
  /// (örn. normal → feint/tracking) dönüştürmek için alan-bazlı kopya.
  Beat copyWith({
    BeatKind? kind,
    DefenseProfile? defense,
    int? damage,
    int? postureDamage,
    GuardDirection? guardDirection,
    bool? punishOnDodge,
  }) {
    return Beat(
      kind: kind ?? this.kind,
      defense: defense ?? this.defense,
      animKey: animKey,
      windup: windup,
      active: active,
      recover: recover,
      gapAfter: gapAfter,
      preWindow: preWindow,
      grace: grace,
      dodgePre: dodgePre,
      damage: damage ?? this.damage,
      postureDamage: postureDamage ?? this.postureDamage,
      guardDirection: guardDirection ?? this.guardDirection,
      punishOnDodge: punishOnDodge ?? this.punishOnDodge,
      mustDefend: mustDefend,
      projectileKey: projectileKey,
      projectileSpeed: projectileSpeed,
      animationBindingId: animationBindingId,
    );
  }

  /// Bu beat'i PARRY etmek oyuncuyu cezalandırır mı? (guardBreak)
  bool get parryPunished => defense == DefenseProfile.guardBreak;

  /// Bu beat'i DODGE etmek oyuncuyu cezalandırır mı? (tracking)
  bool get dodgePunished => defense == DefenseProfile.tracking;

  /// Erken savunmayı boşa düşürüp recovery'ye sokar mı? (feint/delayed)
  bool get punishesEarly =>
      defense == DefenseProfile.feint || defense == DefenseProfile.delayed;
}

/// Bir kombo deseni + havuz seçimi için ağırlık/faz bilgisi.
class ComboPattern {
  final List<Beat> beats;
  final int staggerBonus; // tam parry zincirinin verdiği EKSTRA posture hasarı
  final double weight; // havuzda seçilme ağırlığı
  final int minPhase; // 0 = baştan; 1 = yalnız boss düşük HP fazında

  const ComboPattern(
    this.beats, {
    this.staggerBonus = 14,
    this.weight = 1,
    this.minPhase = 0,
  });

  int get nonFeintCount => beats.where((b) => b.kind != BeatKind.feint).length;
}

/// Tek satır sprite-strip tanımı. Kare karedir: genişlik == cellH.
class SheetSpec {
  final String file;
  final int frames;
  final double cellH;
  const SheetSpec(this.file, this.frames, {this.cellH = 128});
}

class CharacterDef {
  final String id;
  final CharClass cls;
  final String name;
  final String title;
  final String blurb;
  final Map<String, SheetSpec> sheets;
  final List<ComboPattern> combos;
  final double cellPx;
  final double feetV;
  final bool ranged;
  final int maxPosture;
  // Boss'u devirmek için gereken DEATHBLOW (infaz) sayısı (06). Her infaz bir
  // segment/faz siler; sonuncu öldürür. 1 = klasik tek infaz.
  final int deathblowsRequired;

  const CharacterDef({
    required this.id,
    required this.cls,
    required this.name,
    required this.title,
    required this.blurb,
    required this.sheets,
    required this.combos,
    this.cellPx = 224,
    this.feetV = 1.0,
    this.ranged = false,
    this.maxPosture = 100,
    this.deathblowsRequired = 1,
  });

  /// Geriye dönük uyumluluk: tek desen isteyen kod (HUD önizleme, testler)
  /// havuzun ilk desenini "birincil" desen olarak okur.
  ComboPattern get pattern => combos.first;
}

// ============================================================================
//  ORTAK SHEET SETLERİ (tekrarları azaltmak için)
// ============================================================================
const Map<String, SheetSpec> _knightSheets = {
  'idle': SheetSpec('idle.png', 4),
  'walk': SheetSpec('walk.png', 8),
  'run': SheetSpec('run.png', 7),
  'hurt': SheetSpec('hurt.png', 2),
  'dead': SheetSpec('dead.png', 6),
  'attack1': SheetSpec('attack1.png', 5),
  'attack2': SheetSpec('attack2.png', 4),
  'attack3': SheetSpec('attack3.png', 4),
  'defend': SheetSpec('defend.png', 5),
  'protect': SheetSpec('protect.png', 1),
};

// ============================================================================
//  6 KARAKTER
// ============================================================================
const List<CharacterDef> kCharacters = [
  // ----------------------- KNIGHTS (melee) -----------------------
  CharacterDef(
    id: 'knight_1',
    cls: CharClass.knight,
    name: 'ŞÖVALYE I',
    title: 'ÜÇLÜ SERİ',
    blurb: 'Ard arda üç vuruş; ortadaki KIRMIZI — onu kaç, gerisini savuştur.',
    deathblowsRequired: 2,
    sheets: _knightSheets,
    combos: [
      ComboPattern([
        Beat(
          kind: BeatKind.meleeLight,
          animKey: 'attack1',
          animationBindingId: 'knight_1.attack1',
          windup: .34,
          active: .15,
          recover: .22,
          gapAfter: .12,
          preWindow: .12,
          grace: .05,
          dodgePre: .24,
          damage: 14,
          postureDamage: 16,
        ),
        Beat(
          kind: BeatKind.meleeHeavy,
          defense: DefenseProfile.guardBreak,
          animKey: 'attack2',
          animationBindingId: 'knight_1.attack2',
          windup: .44,
          active: .15,
          recover: .26,
          gapAfter: .14,
          dodgePre: .26,
          damage: 18,
          postureDamage: 0,
          punishOnDodge: true,
          mustDefend: true,
        ),
        Beat(
          kind: BeatKind.meleeLight,
          animKey: 'attack3',
          animationBindingId: 'knight_1.attack3',
          windup: .30,
          active: .15,
          recover: .30,
          gapAfter: .30,
          preWindow: .12,
          grace: .05,
          dodgePre: .24,
          damage: 14,
          postureDamage: 16,
        ),
      ], staggerBonus: 16),
    ],
  ),

  CharacterDef(
    id: 'knight_2',
    cls: CharClass.knight,
    name: 'ŞÖVALYE II',
    title: 'AĞIR + İKİLİ HIZLI',
    blurb: 'KIRMIZI ağır açılışı kaç, sonra hızlı ikiliyi savuştur.',
    deathblowsRequired: 2,
    sheets: _knightSheets,
    combos: [
      // Ana desen: KIRMIZI ağır (kaç → açılır) + iki parry.
      ComboPattern([
        Beat(
          kind: BeatKind.meleeHeavy,
          defense: DefenseProfile.guardBreak,
          animKey: 'attack3',
          windup: .55,
          active: .16,
          recover: .40,
          gapAfter: .26,
          dodgePre: .34,
          damage: 24,
          postureDamage: 0,
          punishOnDodge: true,
          mustDefend: true,
        ),
        Beat(
          kind: BeatKind.meleeLight,
          animKey: 'attack1',
          windup: .28,
          active: .13,
          recover: .18,
          gapAfter: .12,
          preWindow: .11,
          grace: .05,
          dodgePre: .22,
          damage: 13,
          postureDamage: 16,
        ),
        Beat(
          kind: BeatKind.meleeLight,
          animKey: 'attack2',
          windup: .28,
          active: .13,
          recover: .26,
          gapAfter: .30,
          preWindow: .11,
          grace: .05,
          dodgePre: .22,
          damage: 14,
          postureDamage: 16,
        ),
      ], staggerBonus: 16),
      // Alternatif: iki parry + KIRMIZI final.
      ComboPattern(
        [
          Beat(
            kind: BeatKind.meleeLight,
            animKey: 'attack1',
            windup: .30,
            active: .14,
            recover: .20,
            gapAfter: .12,
            preWindow: .11,
            grace: .05,
            dodgePre: .22,
            damage: 13,
            postureDamage: 16,
          ),
          Beat(
            kind: BeatKind.meleeHeavy,
            defense: DefenseProfile.guardBreak,
            animKey: 'attack3',
            windup: .48,
            active: .16,
            recover: .38,
            gapAfter: .30,
            dodgePre: .32,
            damage: 22,
            postureDamage: 0,
            punishOnDodge: true,
            mustDefend: true,
          ),
        ],
        staggerBonus: 14,
        weight: 0.8,
      ),
      // Faz 2: MİKİRİ açılışı (delici) — parry'le, dodge ile bastır. Sonra parry.
      ComboPattern(
        [
          Beat(
            kind: BeatKind.meleeHeavy,
            defense: DefenseProfile.thrust,
            animKey: 'attack2',
            windup: .50,
            active: .15,
            recover: .36,
            gapAfter: .20,
            dodgePre: .26,
            damage: 22,
            postureDamage: 0,
            punishOnDodge: true,
            mustDefend: true,
          ),
          Beat(
            kind: BeatKind.meleeLight,
            animKey: 'attack1',
            windup: .26,
            active: .13,
            recover: .22,
            gapAfter: .30,
            preWindow: .11,
            grace: .05,
            dodgePre: .22,
            damage: 13,
            postureDamage: 16,
          ),
        ],
        staggerBonus: 16,
        weight: 0.7,
        minPhase: 1,
      ),
      // Faz 2: ALDATMA tuzağı — parry'le, ORTADAKİ ALDATMA (vuruş gelmez; erken
      // basarsan tuzağa düşersin), sonra GERÇEK vuruş seni cezalandırır (09).
      ComboPattern(
        [
          Beat(
            kind: BeatKind.meleeLight,
            animKey: 'attack1',
            windup: .30,
            active: .13,
            recover: .20,
            gapAfter: .14,
            preWindow: .11,
            grace: .05,
            dodgePre: .22,
            damage: 13,
            postureDamage: 16,
          ),
          Beat(
            kind: BeatKind.feint,
            defense: DefenseProfile.feint,
            animKey: 'attack2',
            windup: .40,
            active: .14,
            recover: .20,
            gapAfter: .10,
            dodgePre: .22,
            damage: 0,
            postureDamage: 0,
          ),
          Beat(
            kind: BeatKind.meleeLight,
            animKey: 'attack3',
            windup: .24,
            active: .13,
            recover: .26,
            gapAfter: .30,
            preWindow: .11,
            grace: .05,
            dodgePre: .22,
            damage: 16,
            postureDamage: 16,
          ),
        ],
        staggerBonus: 16,
        weight: 0.7,
        minPhase: 1,
      ),
      // Faz 2: DELAYED açılış — windup değişken (jitter); eski ritimle erken parry
      // basan ıskalar ve yer. Bekleyip reaktif parry'leyen güvende (09).
      ComboPattern(
        [
          Beat(
            kind: BeatKind.meleeHeavy,
            defense: DefenseProfile.delayed,
            animKey: 'attack3',
            windup: .46,
            active: .15,
            recover: .34,
            gapAfter: .18,
            preWindow: .12,
            grace: .06,
            dodgePre: .26,
            damage: 20,
            postureDamage: 18,
          ),
          Beat(
            kind: BeatKind.meleeLight,
            animKey: 'attack1',
            windup: .26,
            active: .13,
            recover: .22,
            gapAfter: .30,
            preWindow: .11,
            grace: .05,
            dodgePre: .22,
            damage: 13,
            postureDamage: 16,
          ),
        ],
        staggerBonus: 16,
        weight: 0.6,
        minPhase: 1,
      ),
    ],
  ),

  CharacterDef(
    id: 'knight_3',
    cls: CharClass.knight,
    name: 'ŞÖVALYE III',
    title: 'KALKAN KIRICI',
    blurb:
        'Savuştur, ortadaki KALKAN KIRICI KIRMIZI gelince kaç, sonra savuştur.',
    deathblowsRequired: 2,
    sheets: _knightSheets,
    combos: [
      ComboPattern([
        Beat(
          kind: BeatKind.meleeLight,
          animKey: 'attack1',
          windup: .32,
          active: .13,
          recover: .24,
          gapAfter: .14,
          preWindow: .12,
          grace: .05,
          dodgePre: .22,
          damage: 13,
          postureDamage: 16,
        ),
        Beat(
          kind: BeatKind.meleeHeavy,
          defense: DefenseProfile.guardBreak,
          animKey: 'attack3',
          windup: .50,
          active: .16,
          recover: .38,
          gapAfter: .22,
          dodgePre: .30,
          damage: 24,
          postureDamage: 0,
          punishOnDodge: true,
          mustDefend: true,
        ),
        Beat(
          kind: BeatKind.meleeLight,
          animKey: 'attack2',
          windup: .28,
          active: .13,
          recover: .26,
          gapAfter: .30,
          preWindow: .11,
          grace: .05,
          dodgePre: .22,
          damage: 13,
          postureDamage: 14,
        ),
      ], staggerBonus: 18),
      // Alternatif: iki hızlı parry (kırmızı yok).
      ComboPattern(
        [
          Beat(
            kind: BeatKind.meleeLight,
            animKey: 'attack1',
            windup: .28,
            active: .13,
            recover: .20,
            gapAfter: .14,
            preWindow: .11,
            grace: .05,
            dodgePre: .22,
            damage: 12,
            postureDamage: 16,
          ),
          Beat(
            kind: BeatKind.meleeLight,
            animKey: 'attack2',
            windup: .26,
            active: .13,
            recover: .26,
            gapAfter: .30,
            preWindow: .11,
            grace: .05,
            dodgePre: .22,
            damage: 12,
            postureDamage: 14,
          ),
        ],
        staggerBonus: 14,
        weight: 0.7,
      ),
      // Faz 2: ALDATMA + KALKAN KIRICI. Aldatmaya kanıp erken basarsan kırmızıyı
      // (kaçılması gereken) karşılayamazsın (09).
      ComboPattern(
        [
          Beat(
            kind: BeatKind.feint,
            defense: DefenseProfile.feint,
            animKey: 'attack1',
            windup: .38,
            active: .13,
            recover: .18,
            gapAfter: .12,
            dodgePre: .22,
            damage: 0,
            postureDamage: 0,
          ),
          Beat(
            kind: BeatKind.meleeHeavy,
            defense: DefenseProfile.guardBreak,
            animKey: 'attack3',
            windup: .46,
            active: .16,
            recover: .38,
            gapAfter: .30,
            dodgePre: .30,
            damage: 24,
            postureDamage: 0,
            punishOnDodge: true,
            mustDefend: true,
          ),
        ],
        staggerBonus: 14,
        weight: 0.6,
        minPhase: 1,
      ),
    ],
  ),

  // ----------------------- SAMURAI (oyuncu) -----------------------
  CharacterDef(
    id: 'samurai',
    cls: CharClass.knight,
    name: 'SAMURAY',
    title: 'ÜÇLÜ KESİK',
    blurb: 'Ard arda üç vuruş; ortadaki ZORUNLU savunma.',
    sheets: {
      'idle': SheetSpec('idle.png', 6),
      'walk': SheetSpec('walk.png', 9),
      'run': SheetSpec('run.png', 8),
      'hurt': SheetSpec('hurt.png', 3),
      'dead': SheetSpec('dead.png', 6),
      'attack1': SheetSpec('attack1.png', 4),
      'attack2': SheetSpec('attack2.png', 5),
      'attack3': SheetSpec('attack3.png', 4),
      'defend': SheetSpec('defend.png', 2),
      'protect': SheetSpec('protect.png', 2),
    },
    combos: [
      ComboPattern([
        Beat(
          kind: BeatKind.meleeLight,
          animKey: 'attack1',
          windup: .34,
          active: .15,
          recover: .22,
          gapAfter: .12,
          preWindow: .12,
          grace: .05,
          dodgePre: .24,
          damage: 14,
        ),
        Beat(
          kind: BeatKind.meleeLight,
          animKey: 'attack2',
          windup: .30,
          active: .15,
          recover: .22,
          gapAfter: .12,
          preWindow: .10,
          grace: .045,
          dodgePre: .20,
          damage: 16,
          mustDefend: true,
        ),
        Beat(
          kind: BeatKind.meleeLight,
          animKey: 'attack3',
          windup: .30,
          active: .15,
          recover: .30,
          gapAfter: .30,
          preWindow: .12,
          grace: .05,
          dodgePre: .24,
          damage: 14,
        ),
      ], staggerBonus: 16),
    ],
  ),

  // ----------------------- WIZARDS (ranged) -----------------------
  CharacterDef(
    id: 'fire_wizard',
    cls: CharClass.wizard,
    name: 'ATEŞ BÜYÜCÜSÜ',
    title: 'ALEV YAĞMURU',
    blurb: 'Ağır alev topu (parry\'le yansıt) sonra hızlı alev hüzmesi.',
    ranged: true,
    sheets: {
      'idle': SheetSpec('idle.png', 7),
      'walk': SheetSpec('walk.png', 6),
      'run': SheetSpec('run.png', 8),
      'attack1': SheetSpec('attack1.png', 4),
      'attack2': SheetSpec('attack2.png', 4),
      'hurt': SheetSpec('hurt.png', 3),
      'dead': SheetSpec('dead.png', 6),
      'fireball': SheetSpec('fireball.png', 8),
      'flame_jet': SheetSpec('flame_jet.png', 14),
    },
    combos: [
      ComboPattern([
        Beat(
          kind: BeatKind.ranged,
          defense: DefenseProfile.ranged,
          animKey: 'attack1',
          windup: .60,
          active: .12,
          recover: .34,
          gapAfter: .30,
          preWindow: .16,
          grace: .10,
          damage: 22,
          postureDamage: 26,
          projectileKey: 'fireball',
          projectileSpeed: 540,
        ),
        Beat(
          kind: BeatKind.ranged,
          defense: DefenseProfile.ranged,
          animKey: 'attack2',
          windup: .30,
          active: .12,
          recover: .30,
          gapAfter: .30,
          preWindow: .12,
          grace: .07,
          damage: 14,
          postureDamage: 14,
          projectileKey: 'flame_jet',
          projectileSpeed: 760,
        ),
      ], staggerBonus: 16),
    ],
  ),

  CharacterDef(
    id: 'lightning_mage',
    cls: CharClass.wizard,
    name: 'ŞİMŞEK BÜYÜCÜSÜ',
    title: 'ŞİMŞEK SALVOSU',
    blurb: 'Üç hızlı şimşek; ortadaki ZORUNLU. Parry yansıtır.',
    ranged: true,
    sheets: {
      'idle': SheetSpec('idle.png', 7),
      'walk': SheetSpec('walk.png', 7),
      'run': SheetSpec('run.png', 8),
      'attack1': SheetSpec('attack1.png', 10),
      'attack2': SheetSpec('attack2.png', 4),
      'hurt': SheetSpec('hurt.png', 3),
      'dead': SheetSpec('dead.png', 5),
      'light_ball': SheetSpec('light_ball.png', 7),
    },
    combos: [
      ComboPattern([
        Beat(
          kind: BeatKind.ranged,
          defense: DefenseProfile.ranged,
          animKey: 'attack1',
          windup: .30,
          active: .10,
          recover: .14,
          gapAfter: .12,
          preWindow: .10,
          grace: .06,
          damage: 12,
          postureDamage: 14,
          projectileKey: 'light_ball',
          projectileSpeed: 900,
        ),
        Beat(
          kind: BeatKind.ranged,
          defense: DefenseProfile.ranged,
          animKey: 'attack1',
          windup: .24,
          active: .10,
          recover: .14,
          gapAfter: .12,
          preWindow: .09,
          grace: .05,
          damage: 14,
          postureDamage: 16,
          mustDefend: true,
          projectileKey: 'light_ball',
          projectileSpeed: 920,
        ),
        Beat(
          kind: BeatKind.ranged,
          defense: DefenseProfile.ranged,
          animKey: 'attack1',
          windup: .24,
          active: .10,
          recover: .18,
          gapAfter: .30,
          preWindow: .10,
          grace: .06,
          damage: 12,
          postureDamage: 14,
          projectileKey: 'light_ball',
          projectileSpeed: 940,
        ),
      ], staggerBonus: 18),
    ],
  ),

  CharacterDef(
    id: 'wanderer_magican',
    cls: CharClass.wizard,
    name: 'GEZGİN BÜYÜCÜ',
    title: 'BÜYÜ KÜRESİ',
    blurb: 'Hızlı ok, ardından yavaş ağır küre. Parry yansıtır.',
    ranged: true,
    sheets: {
      'idle': SheetSpec('idle.png', 8),
      'walk': SheetSpec('walk.png', 7),
      'run': SheetSpec('run.png', 8),
      'attack1': SheetSpec('attack1.png', 7),
      'attack2': SheetSpec('attack2.png', 9),
      'hurt': SheetSpec('hurt.png', 4),
      'dead': SheetSpec('dead.png', 4),
      'magic_arrow': SheetSpec('magic_arrow.png', 6),
      'magic_sphere': SheetSpec('magic_sphere.png', 16),
    },
    combos: [
      ComboPattern([
        Beat(
          kind: BeatKind.ranged,
          defense: DefenseProfile.ranged,
          animKey: 'attack1',
          windup: .30,
          active: .10,
          recover: .18,
          gapAfter: .16,
          preWindow: .12,
          grace: .06,
          damage: 12,
          postureDamage: 14,
          projectileKey: 'magic_arrow',
          projectileSpeed: 860,
        ),
        Beat(
          kind: BeatKind.ranged,
          defense: DefenseProfile.ranged,
          animKey: 'attack2',
          windup: .58,
          active: .14,
          recover: .38,
          gapAfter: .30,
          preWindow: .18,
          grace: .10,
          damage: 24,
          postureDamage: 26,
          projectileKey: 'magic_sphere',
          projectileSpeed: 480,
        ),
      ], staggerBonus: 16),
    ],
  ),
];

List<CharacterDef> charactersOf(CharClass c) =>
    kCharacters.where((e) => e.cls == c).toList();

CharacterDef characterById(String id) =>
    kCharacters.firstWhere((e) => e.id == id);

// ----------------------------------------------------------------------------
//  DENEME SÜRÜMÜ ROSTERİ
//    Oyuncu sabit: SAMURAY (samurai). Rakip: aşağıdaki iki şövalyeden biri.
// ----------------------------------------------------------------------------
CharacterDef get kPlayerDef => characterById('samurai');

const List<String> kOpponentIds = ['knight_2', 'knight_3'];

List<CharacterDef> get kOpponents => kOpponentIds.map(characterById).toList();

const String kTestOpponentId = 'knight_1';

CharacterDef get kTestOpponent => characterById(kTestOpponentId);

// images.load için sprite sheet yolu:
String charSheetPath(CharacterDef d, String animKey) =>
    'chars/${d.id}/${d.sheets[animKey]!.file}';
