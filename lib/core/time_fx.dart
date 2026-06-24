// ============================================================================
//  TIME FX  —  hitstop / slow-mo / screen-shake zaman ölçeği yardımcısı
// ----------------------------------------------------------------------------
//  game.dart'tan ayrılan saf zaman/FX durumu (Faz A). Flame/oyun katmanına
//  bağlanmaz; yalnızca efektif zaman ölçeğini ve shake offset'ini üretir.
//  game.dart bu birime delege eder — davranış birebir korunur.
// ============================================================================
import 'dart:math';
import 'dart:ui' show Offset;

class TimeFx {
  // Hitstop: temas anında oyunu kısa süre "donuk" hissettiren zaman ölçeği.
  double _hitstop = 0;
  // Slow-mo: hitstop'tan AYRI, daha uzun ve daha hafif zaman ölçeği yolu
  // (deathblow / faz geçişi sineması). Hitstop varken o önceliklidir (11).
  double _slowmo = 0;
  double _slowmoScale = 0.3;
  // Screen-shake: sönümlenen küçük kamera sarsıntısı (heavy/posture/deathblow).
  double _shakeT = 0;
  double _shakeDur = 0;
  double _shakeAmp = 0;

  void requestHitstop(double d) {
    if (d > _hitstop) _hitstop = d;
  }

  // Deathblow/faz sineması: hitstop'u bozmadan daha uzun, daha hafif yavaşlatma.
  void requestSlowmo(double duration, double scale) {
    if (duration > _slowmo) {
      _slowmo = duration;
      _slowmoScale = scale;
    }
  }

  // Hafif kamera sarsıntısı (genlik px, süre s). Genlik çağıran tarafında
  // (game.dart) screenShakeScale ile ölçeklenmiş gelir. Daha güçlü istek
  // öncekini ezer.
  void requestShake(double amplitude, double duration) {
    if (amplitude <= 0 || duration <= 0) return;
    if (amplitude >= _shakeAmp || _shakeT <= 0) {
      _shakeAmp = amplitude;
      _shakeDur = duration;
      _shakeT = duration;
    }
  }

  // Maç sıfırlamalarında çağrılır: aktif hitstop/slow-mo/shake'i temizler
  // (game.dart'taki eski `_hitstop = 0; _slowmo = 0; _shakeT = 0;` ile birebir).
  void reset() {
    _hitstop = 0;
    _slowmo = 0;
    _shakeT = 0;
  }

  // Zaman ölçeği: hitstop (kısa sert donma) önceliklidir; yoksa slow-mo
  // (deathblow/faz, daha uzun/hafif). İkisi de gerçek dt ile azalır. Shake
  // zamanlayıcısı da gerçek dt ile akar. Efektif ölçeği döndürür.
  double update(double dt) {
    double scale = 1.0;
    if (_hitstop > 0) {
      _hitstop = (_hitstop - dt).clamp(0, 999).toDouble();
      scale = 0.06;
    } else if (_slowmo > 0) {
      _slowmo = (_slowmo - dt).clamp(0, 999).toDouble();
      scale = _slowmoScale;
    }
    if (_shakeT > 0) _shakeT = (_shakeT - dt).clamp(0, 999).toDouble();
    return scale;
  }

  Offset shakeOffset() {
    if (_shakeT <= 0 || _shakeDur <= 0) return Offset.zero;
    final t = (_shakeT / _shakeDur).clamp(0.0, 1.0);
    final mag = _shakeAmp * t; // doğrusal sönüm
    return Offset(sin(_shakeT * 92) * mag, cos(_shakeT * 67) * mag * 0.6);
  }
}
