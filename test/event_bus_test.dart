// EventBus davranış testleri (Faz B): senkron FIFO yayım, çoklu abone,
// abone-içi exception izolasyonu, unsubscribe ve dispatch-sırasında-kaldırma
// güvenliği.

import 'package:boss_parry_arena/combat/rules/combat_event.dart';
import 'package:boss_parry_arena/core/event_bus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EventBus', () {
    test('emit olayı aboneye iletir', () {
      final bus = EventBus();
      final received = <CombatEvent>[];
      bus.subscribe(received.add);

      bus.emit(const PostureBroken());

      expect(received, hasLength(1));
      expect(received.single, isA<PostureBroken>());
    });

    test('çoklu abone ekleniş sırasıyla (FIFO) çağrılır', () {
      final bus = EventBus();
      final order = <String>[];
      bus.subscribe((_) => order.add('a'));
      bus.subscribe((_) => order.add('b'));
      bus.subscribe((_) => order.add('c'));

      bus.emit(const PostureBroken());

      expect(order, ['a', 'b', 'c']);
    });

    test('bir abonenin hatası diğer aboneleri durdurmaz', () {
      final bus = EventBus();
      final reached = <String>[];
      bus.subscribe((_) => throw StateError('patladı'));
      bus.subscribe((_) => reached.add('ikinci'));

      expect(() => bus.emit(const PostureBroken()), returnsNormally);
      expect(reached, ['ikinci']);
    });

    test('unsubscribe aboneliği kaldırır', () {
      final bus = EventBus();
      var count = 0;
      final off = bus.subscribe((_) => count++);

      bus.emit(const PostureBroken());
      off();
      bus.emit(const PostureBroken());

      expect(count, 1);
    });

    test(
      'dispatch sırasında abone kaldırılsa da o emit güvenli tamamlanır',
      () {
        final bus = EventBus();
        final order = <String>[];
        late void Function() off;
        bus.subscribe((_) {
          order.add('first');
          off(); // yayım sürerken üçüncü aboneyi kaldır
        });
        bus.subscribe((_) => order.add('second'));
        off = bus.subscribe((_) => order.add('third'));

        bus.emit(const PostureBroken());
        // Kopya üzerinde gezinildiği için bu emit'te üçü de çağrılır.
        expect(order, ['first', 'second', 'third']);

        // Sonraki emit'te üçüncü artık yok.
        order.clear();
        bus.emit(const PostureBroken());
        expect(order, ['first', 'second']);
      },
    );

    test('farklı olay tipleri abonelere aynen geçer', () {
      final bus = EventBus();
      final received = <CombatEvent>[];
      bus.subscribe(received.add);

      bus.emit(const DamageApplied(20, toBoss: true));
      bus.emit(const ParrySucceeded(perfect: true));
      bus.emit(const SfxRequested(SfxCue.parryPerfect));

      expect(received[0], isA<DamageApplied>());
      expect((received[0] as DamageApplied).amount, 20);
      expect((received[0] as DamageApplied).toBoss, isTrue);
      expect((received[1] as ParrySucceeded).perfect, isTrue);
      expect((received[2] as SfxRequested).cue, SfxCue.parryPerfect);
    });
  });
}
