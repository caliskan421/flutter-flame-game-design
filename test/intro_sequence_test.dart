import 'package:boss_parry_arena/content/intro_sequence.dart';
import 'package:flutter_test/flutter_test.dart';

// "s-cedilla" diskteki asset adlariyla eslesmesi icin NFD formunda olmali:
// 's' + U+0327 (combining cedilla). NFC tek kod noktasi (U+015F) DEGIL.
const String _sh = 'ş'; // NFD: 's' + combining cedilla (U+0327)

void main() {
  group('combat intro sequence (Faz A veri tasimasi)', () {
    test('cue sayisi ve sirasi birebir korunur', () {
      final cues = kCombatIntroSequence.cues;
      expect(cues, hasLength(6));

      expect(cues.map((c) => c.image).toList(), [
        '${_sh}1.png',
        's1.png',
        '${_sh}2.png',
        's2.png',
        '${_sh}3.png',
        's3.png',
      ]);
      expect(cues.map((c) => c.audio).toList(), [
        '${_sh}1.mp3',
        's1.mp3',
        '${_sh}2.mp3',
        's2.mp3',
        '${_sh}3.mp3',
        's3.mp3',
      ]);
      expect(cues.map((c) => c.side).toList(), [
        IntroSide.right,
        IntroSide.left,
        IntroSide.right,
        IntroSide.left,
        IntroSide.right,
        IntroSide.left,
      ]);
    });

    test('acilis/kapanis muzigi eski sabitlerle ayni', () {
      expect(
        kCombatIntroSequence.openingMusic,
        'backgroung/Blood Oath March (1).mp3',
      );
      expect(
        kCombatIntroSequence.closingMusic,
        'backgroung/Cathedral of Ash (2).mp3',
      );
    });

    // macOS asset anahtarlari NFD; cedilla NFC (U+015F) olursa Image.asset
    // 'giris senaryo/...' anahtarini bulamaz. Bu test NFD formunu korur.
    test('s-cedilla dosya adlari NFD (U+0327) formunda', () {
      final images = kCombatIntroSequence.cues.map((c) => c.image).toList();
      final withCedilla =
          images.where((s) => s.codeUnits.contains(0x0327)).toList();
      expect(withCedilla, hasLength(3));
      for (final img in images) {
        expect(img.codeUnits.contains(0x015F), isFalse, reason: img);
      }
    });
  });
}
