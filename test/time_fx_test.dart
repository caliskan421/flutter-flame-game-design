import 'package:boss_parry_arena/core/time_fx.dart';
import 'package:flutter_test/flutter_test.dart';

// TimeFx Faz A'da game.dart'tan birebir taşındı. Bu test, eski koddaki sayısal
// sabitleri ve öncelik sırasını (hitstop > slow-mo > normal) korur.
void main() {
  group('TimeFx (Faz A — davranış koruyan)', () {
    test('varsayılan ölçek 1.0, shake offset yok', () {
      final fx = TimeFx();
      expect(fx.update(0.016), 1.0);
      expect(fx.shakeOffset(), Offset.zero);
    });

    test('hitstop aktifken ölçek 0.06 ve önceliklidir', () {
      final fx = TimeFx();
      fx.requestSlowmo(1.0, 0.5); // aynı anda slow-mo da iste
      fx.requestHitstop(0.1);
      // hitstop > slow-mo: ölçek hitstop'un 0.06'sı olmalı.
      expect(fx.update(0.016), 0.06);
    });

    test('hitstop bitince slow-mo ölçeği devralır', () {
      final fx = TimeFx();
      fx.requestSlowmo(1.0, 0.5);
      expect(fx.update(0.016), 0.5);
    });

    test('requestHitstop yalnız daha uzun süreyi yükseltir', () {
      final fx = TimeFx();
      fx.requestHitstop(0.05);
      fx.requestHitstop(0.02); // kısa olan ezmez
      // 0.03 ilerlet: hâlâ 0.05-0.03=0.02 kalır → hitstop ölçeği sürer.
      expect(fx.update(0.03), 0.06);
    });

    test('reset hitstop/slow-mo/shake zamanlayıcılarını sıfırlar', () {
      final fx = TimeFx();
      fx.requestHitstop(0.2);
      fx.requestSlowmo(0.5, 0.4);
      fx.requestShake(10, 0.3);
      fx.reset();
      expect(fx.update(0.016), 1.0); // hitstop+slowmo temizlendi
      expect(fx.shakeOffset(), Offset.zero); // shake temizlendi
    });

    test('requestShake genliği <=0 ise yok sayılır', () {
      final fx = TimeFx();
      fx.requestShake(0, 0.3);
      expect(fx.shakeOffset(), Offset.zero);
    });

    test('aktif shake sıfırdan farklı offset üretir', () {
      final fx = TimeFx();
      fx.requestShake(10, 0.3);
      // Süre dolmadan offset sıfırdan farklı olmalı (faz başında t≈1).
      expect(fx.shakeOffset(), isNot(Offset.zero));
    });
  });
}
