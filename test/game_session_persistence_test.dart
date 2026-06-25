import 'package:boss_parry_arena/domain/game_session.dart';
import 'package:boss_parry_arena/domain/save_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeStore implements SaveStore {
  String? data;
  @override
  Future<String?> read() async => data;
  @override
  Future<void> write(String contents) async => data = contents;
  @override
  Future<void> clear() async => data = null;
}

void main() {
  group('GameSession kalıcılık (merkezi)', () {
    test('mutasyon → otomatik persist; yeni oturum aynı store → yükler', () async {
      final store = FakeStore();

      final s1 = GameSession();
      await s1.attachPersistence(SaveRepository(store));
      expect(s1.hasProgress, isFalse);

      s1.setFlag('boss_knight_1_defeated');
      s1.giveResource('honor', 1);
      s1.markEncounterCompleted('ash_gate');
      // persist fire-and-forget; microtask'ların boşalmasını bekle.
      await Future<void>.delayed(Duration.zero);
      expect(store.data, isNotNull);

      // Oyunu "kapat-aç": aynı store ile yeni oturum.
      final s2 = GameSession();
      await s2.attachPersistence(SaveRepository(store));
      expect(s2.hasProgress, isTrue);
      expect(s2.scenario.hasFlag('boss_knight_1_defeated'), isTrue);
      expect(s2.scenario.resource('honor'), 1);
      expect(s2.scenario.isCompleted('ash_gate'), isTrue);
    });

    test('resetProgress → bellek ve disk temizlenir', () async {
      final store = FakeStore();
      final s = GameSession();
      await s.attachPersistence(SaveRepository(store));
      s.setFlag('x');
      s.giveResource('honor', 5);
      await Future<void>.delayed(Duration.zero);

      await s.resetProgress();
      expect(s.hasProgress, isFalse);
      expect(s.scenario.flags, isEmpty);
      expect(store.data, isNull);
    });

    test('repository bağlı değilken persist çökmez (opsiyonel katman)', () {
      final s = GameSession();
      expect(() {
        s.setFlag('x'); // persist no-op (repo yok)
        s.persist();
      }, returnsNormally);
    });
  });
}
