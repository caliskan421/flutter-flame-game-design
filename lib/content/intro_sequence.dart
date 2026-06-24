// ============================================================================
//  INTRO SEQUENCE  —  combat giriş senaryo sunumunun veri tanimi (Faz A)
// ----------------------------------------------------------------------------
//  CombatIntroOverlay'in eskiden hard-coded tasidigi replik/portre cue'lari ve
//  muzik parcalari burada VERI olarak durur. Overlay bu veriyi yalnizca render
//  eder. Gorsel/isitsel sonuc birebir aynidir.
//
//  NOT: Portre dosya adlarindaki "ş" karakteri, diskteki asset adlariyla
//  (giriş senaryo/...) birebir eslesmesi icin NFD formunda ('s' + U+0327
//  combining cedilla) yazilmistir; NFC ('ş' tek kod noktasi) asset anahtarini
//  bulamaz. Bu yuzden bu dosyayi degistirirken kopyalayarak tasi.
// ============================================================================

/// Portrenin ekranin hangi yaninda belirecegi.
enum IntroSide { left, right }

/// Tek bir giris cue'su: portre gorseli + diyalog sesi + ekran yani.
class DialogueCueDef {
  /// 'giriş senaryo/' klasoru altindaki portre dosyasi (orn. 'ş1.png').
  final String image;

  /// Diyalog ses dosyasi (Sfx.playIntroDialogue'a verilir).
  final String audio;

  /// Portrenin belirecegi yan.
  final IntroSide side;

  const DialogueCueDef(this.image, this.audio, this.side);
}

/// Bir combat giris sunumunun tam veri tanimi: acilis/kapanis muzigi + cue'lar.
class IntroSequenceDef {
  /// Acilis (giris) fonu — sunum boyunca calar.
  final String openingMusic;

  /// Cue'lar bitince gecilen kapanis fonu (mac oncesi).
  final String closingMusic;

  /// Sirali portre/diyalog cue'lari.
  final List<DialogueCueDef> cues;

  const IntroSequenceDef({
    required this.openingMusic,
    required this.closingMusic,
    required this.cues,
  });
}

/// Mevcut combat giris sunumu (game.dart/overlays.dart'tan birebir tasindi).
const IntroSequenceDef kCombatIntroSequence = IntroSequenceDef(
  openingMusic: 'backgroung/Blood Oath March (1).mp3',
  closingMusic: 'backgroung/Cathedral of Ash (2).mp3',
  cues: [
    DialogueCueDef('ş1.png', 'ş1.mp3', IntroSide.right),
    DialogueCueDef('s1.png', 's1.mp3', IntroSide.left),
    DialogueCueDef('ş2.png', 'ş2.mp3', IntroSide.right),
    DialogueCueDef('s2.png', 's2.mp3', IntroSide.left),
    DialogueCueDef('ş3.png', 'ş3.mp3', IntroSide.right),
    DialogueCueDef('s3.png', 's3.mp3', IntroSide.left),
  ],
);
