import 'package:boss_parry_arena/combat/sim/posture_system.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PostureSystem', () {
    test('başlangıçta tam dolu', () {
      final p = PostureSystem(60);
      expect(p.max, 60);
      expect(p.value, 60);
      expect(p.display, 60);
    });

    test('hasar değeri düşürür, kırılma eşiğine inmeden false döner', () {
      final p = PostureSystem(60);
      final broke = p.applyDamage(20, dying: false, staggered: false);
      expect(broke, isFalse);
      expect(p.value, 40);
    });

    test('denge 0 olunca kırılır (true) ve clamp ile negatif olmaz', () {
      final p = PostureSystem(30);
      final broke = p.applyDamage(50, dying: false, staggered: false);
      expect(broke, isTrue);
      expect(p.value, 0);
    });

    test('zaten staggered iken yeniden kırılmaz', () {
      final p = PostureSystem(30);
      final broke = p.applyDamage(50, dying: false, staggered: true);
      expect(broke, isFalse);
      expect(p.value, 0);
    });

    test('dying veya dmg<=0 ise hasar uygulanmaz', () {
      final p = PostureSystem(40);
      expect(p.applyDamage(10, dying: true, staggered: false), isFalse);
      expect(p.value, 40);
      expect(p.applyDamage(0, dying: false, staggered: false), isFalse);
      expect(p.value, 40);
    });

    test('regen yalnız gecikmeden sonra ve stagger dışında işler', () {
      final p = PostureSystem(100);
      p.applyDamage(40, dying: false, staggered: false); // value=60, idle sıfır
      // Gecikme penceresi (1.1s) dolmadan regen yok.
      p.tickRegen(1.0, staggered: false);
      expect(p.value, 60);
      // Gecikme aşıldıktan sonra regen başlar (8/s).
      p.tickRegen(0.2, staggered: false); // toplam idle 1.2 > 1.1
      expect(p.value, closeTo(60 + 8 * 0.2, 1e-9));
    });

    test('stagger sırasında regen olmaz', () {
      final p = PostureSystem(100);
      p.applyDamage(40, dying: false, staggered: false);
      p.tickRegen(2.0, staggered: true);
      expect(p.value, 60);
    });

    test('regen max üstüne çıkmaz', () {
      final p = PostureSystem(50);
      p.applyDamage(5, dying: false, staggered: false); // value=45
      p.tickRegen(2.0, staggered: false); // idle>1.1, +16 → clamp 50
      expect(p.value, 50);
    });

    test('forceFull ve reset tepeye çeker', () {
      final p = PostureSystem(80);
      p.applyDamage(30, dying: false, staggered: false);
      p.forceFull();
      expect(p.value, 80);
      p.applyDamage(30, dying: false, staggered: false);
      p.reset();
      expect(p.value, 80);
      expect(p.display, 80);
    });

    test('tickDisplay gerçek değere doğru yumuşar', () {
      final p = PostureSystem(100);
      p.applyDamage(
        50,
        dying: false,
        staggered: false,
      ); // value=50, display=100
      p.tickDisplay(0.05); // display 50'ye doğru yaklaşır ama tam ulaşmaz
      expect(p.display, lessThan(100));
      expect(p.display, greaterThan(50));
    });
  });
}
