// ============================================================================
//  SES  —  düşük gecikmeli dövüş efektleri + döngü arka plan müziği
// ----------------------------------------------------------------------------
//  Her efekt önceden bir AudioPool'a yüklenir (birden çok hazır oynatıcı). Tuşa
//  basıldığı/temas çözüldüğü AN `pool.start()` çağrılır; bu, dosyayı o anda
//  yüklemekten çok daha hızlıdır ve ardışık vuruşlarda kesilme/gecikme olmaz.
//
//  Eşleme (kullanıcı talebi):
//    parry  (kılıç çarpışması) → başarılı PARRY anında
//    dodge  (geri sıçrama)     → başarılı SHIFT kaçışında
//    hit    (saplanma)         → savunulamayan DARBE yendiğinde
//    death  = hit + swordDrop  → ölümden hemen önce (saplanma → kılıç düşürme)
//
//  Tüm çağrılar "ateşle-unut"tur (await edilmez) → oyun döngüsünü bloklamaz.
// ============================================================================

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

class Sfx {
  Sfx._();

  static AudioPool? _parry;
  static AudioPool? _dodge;
  static AudioPool? _mass;
  static AudioPool? _hit;
  static AudioPool? _swordDrop;

  static bool _ready = false;
  static bool _bgmReady = false;
  static String? _bgmTrack;
  static double _bgmVolume = 0;

  static const double bgmFullVolume = 0.36;
  static const double bgmDuckedVolume = 0.14;

  // Uygulama açılışında bir kez çağrılır. Havuzlar paralel hazırlanır; biri
  // yüklenemezse (ör. ses cihazı yok) sessizce yutulur — oyun yine de çalışır.
  static Future<void> init() async {
    if (_ready) return;
    _ready = true;
    // Varsayılan prefix zaten 'assets/audio/'.
    try {
      final results = await Future.wait([
        FlameAudio.createPool('effect/parry.mp3', maxPlayers: 4),
        FlameAudio.createPool('effect/dodge.mp3', maxPlayers: 3),
        FlameAudio.createPool('effect/mass.mp3', maxPlayers: 3),
        FlameAudio.createPool('effect/hit.mp3', maxPlayers: 4),
        FlameAudio.createPool('effect/sword_drop.mp3', maxPlayers: 2),
      ]);
      _parry = results[0];
      _dodge = results[1];
      _mass = results[2];
      _hit = results[3];
      _swordDrop = results[4];
    } catch (e) {
      debugPrint('Sfx.init başarısız: $e');
    }
  }

  static Future<void> startBackgroundMusic({
    String file = 'backgroung/Blood Oath March (1).mp3',
    double volume = bgmFullVolume,
  }) async {
    try {
      if (!_bgmReady) {
        _bgmReady = true;
        await FlameAudio.bgm.initialize();
      }
      await FlameAudio.bgm.play(file, volume: volume);
      _bgmTrack = file;
      _bgmVolume = volume;
    } catch (e) {
      debugPrint('Arka plan müziği başlatılamadı: $e');
    }
  }

  static Future<void> setBackgroundVolume(double volume) async {
    if (!_bgmReady || !FlameAudio.bgm.isPlaying) return;
    try {
      _bgmVolume = volume.clamp(0, 1).toDouble();
      await FlameAudio.bgm.audioPlayer.setVolume(_bgmVolume);
    } catch (e) {
      debugPrint('Arka plan müziği sesi ayarlanamadı: $e');
    }
  }

  static Future<void> duckBackgroundMusic() =>
      setBackgroundVolume(bgmDuckedVolume);

  static Future<void> restoreBackgroundMusic() =>
      setBackgroundVolume(bgmFullVolume);

  static Future<void> fadeBackgroundVolume(
    double target, {
    Duration duration = const Duration(milliseconds: 700),
  }) async {
    if (!_bgmReady || !FlameAudio.bgm.isPlaying) return;
    const steps = 24;
    final start = _bgmVolume;
    final stepMs = (duration.inMilliseconds / steps).round();
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      await setBackgroundVolume(start + (target - start) * t);
      await Future.delayed(Duration(milliseconds: stepMs));
    }
  }

  static Future<void> stopBackgroundMusic({
    Duration fadeDuration = const Duration(milliseconds: 900),
  }) async {
    try {
      await fadeBackgroundVolume(0, duration: fadeDuration);
      await FlameAudio.bgm.stop();
      _bgmTrack = null;
      _bgmVolume = 0;
    } catch (e) {
      debugPrint('Arka plan müziği durdurulamadı: $e');
    }
  }

  static Future<void> playIntroDialogue(String file) async {
    AudioPlayer? player;
    try {
      player = AudioPlayer()..audioCache = AudioCache(prefix: '');
      await player.setReleaseMode(ReleaseMode.release);
      await player.play(
        AssetSource('giriş senaryo/$file'),
        volume: 1,
        mode: PlayerMode.mediaPlayer,
      );
      await player.onPlayerComplete.first;
    } catch (e) {
      debugPrint('Diyalog sesi çalınamadı ($file): $e');
    } finally {
      await player?.dispose();
    }
  }

  static String? get backgroundTrack => _bgmTrack;

  static void _play(AudioPool? pool, {double volume = 1.0}) {
    if (pool == null) return;
    // start() Future döndürür; await ETMEYİZ → anlık, bloklamayan geri bildirim.
    pool.start(volume: volume);
  }

  /// Başarılı parry: kılıçların çarpışma sesi.
  static void parry() => _play(_parry, volume: 0.9);

  /// Başarılı SHIFT dodge: geri sıçrama/kütle hareketi sesi.
  static void dodge() => _play(_mass, volume: 0.9);

  /// Savunulamayan darbe: saplanma.
  static void hit() => _play(_hit, volume: 1.0);

  /// Ölüm finali: kılıcın yere düşmesi (saplanmadan kısa süre sonra).
  static void swordDrop() => _play(_swordDrop, volume: 0.95);

  // --- SEMANTİK ALIAS'LAR (mevcut havuzları farklı şiddette kullanır) ---
  /// Geç/blok savunma: parry sesinin daha tok hali.
  static void block() => _play(_parry, volume: 0.6);

  /// Boş saldırı (whiff): hafif hava kesme hissi.
  static void whiff() => _play(_dodge, volume: 0.4);

  /// Denge kırılması: ağır saplanma vurgusu.
  static void postureBreak() => _play(_hit, volume: 1.0);

  /// Ağır saldırı isabeti.
  static void heavyHit() => _play(_hit, volume: 1.0);
}
