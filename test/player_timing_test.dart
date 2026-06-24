// Player'ın PUBLIC zamanlama API'sinin Faz C taşımasından sonra eski sabit
// değerlerle BİREBİR aynı kaldığını doğrudan kilitler (move_def alias wiring'i +
// dodgeInvulnerableAt'ın timeline yolu üzerinden sınır davranışı). boss.dart ve
// diğer birim testler bu statik üyeleri okuduğu için sapma regresyon olur.

import 'package:boss_parry_arena/player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Player süre alias\'ları eski değerlerle birebir', () {
    test('parry pencereleri', () {
      expect(Player.parryWindowDuration, 0.13);
      expect(Player.lowParryWindowDuration, 0.18);
    });
    test('light saldırı fazları', () {
      expect(Player.atkWindup, 0.07);
      expect(Player.atkActive, 0.10);
      expect(Player.atkRecover, 0.18);
    });
    test('heavy saldırı fazları', () {
      expect(Player.heavyAtkWindup, 0.24);
      expect(Player.heavyAtkActive, 0.12);
      expect(Player.heavyAtkRecover, 0.42);
    });
    test('dodge pencere + i-frame + perfect', () {
      expect(Player.dodgeWindowDuration, 0.20);
      expect(Player.dodgeInvulnFrom, 0.02);
      expect(Player.dodgeInvulnTo, 0.20);
      expect(Player.perfectDodgeUntil, 0.11);
    });
  });

  group('dodgeInvulnerableAt (timeline yolu) sınır davranışı korunur', () {
    test('i-frame içi true (sınırlar dahil)', () {
      expect(Player.dodgeInvulnerableAt(0.02), isTrue);
      expect(Player.dodgeInvulnerableAt(0.11), isTrue);
      expect(Player.dodgeInvulnerableAt(0.20), isTrue);
    });
    test('i-frame dışı false (greed cezası)', () {
      expect(Player.dodgeInvulnerableAt(0.0), isFalse);
      expect(Player.dodgeInvulnerableAt(0.019), isFalse);
      expect(Player.dodgeInvulnerableAt(0.21), isFalse);
    });
  });
}
