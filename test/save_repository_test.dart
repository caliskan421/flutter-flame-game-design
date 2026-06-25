import 'dart:convert';

import 'package:boss_parry_arena/core/shared_prefs_save_store.dart';
import 'package:boss_parry_arena/domain/save_repository.dart';
import 'package:boss_parry_arena/domain/save_state.dart';
import 'package:boss_parry_arena/domain/scenario_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory SaveStore — repository mantığını Flutter olmadan test eder.
class FakeStore implements SaveStore {
  String? data;
  @override
  Future<String?> read() async => data;
  @override
  Future<void> write(String contents) async => data = contents;
  @override
  Future<void> clear() async => data = null;
}

SaveState _sampleSave() => SaveState.fromScenario(
      ScenarioState()
        ..setFlag('boss_knight_1_defeated')
        ..giveResource('honor', 2)
        ..markCompleted('ash_gate'),
    );

void main() {
  group('SaveRepository (fake store)', () {
    test('save → load round-trip', () async {
      final repo = SaveRepository(FakeStore());
      await repo.save(_sampleSave());
      final loaded = await repo.load();
      expect(loaded, isNotNull);
      expect(loaded!.flags, contains('boss_knight_1_defeated'));
      expect(loaded.resources['honor'], 2);
      expect(loaded.completedEncounters, ['ash_gate']);
    });

    test('kayıt yokken load → null', () async {
      expect(await SaveRepository(FakeStore()).load(), isNull);
    });

    test('bozuk JSON → null (çökme yok)', () async {
      final store = FakeStore()..data = '{ this is not json';
      expect(await SaveRepository(store).load(), isNull);
    });

    test('JSON dizi/obje değil → null', () async {
      final store = FakeStore()..data = '"just a string"';
      expect(await SaveRepository(store).load(), isNull);
    });

    test('uyumsuz şema sürümü → null (güvenli sıfırla)', () async {
      final store = FakeStore()
        ..data = jsonEncode({'version': 999, 'flags': ['x']});
      expect(await SaveRepository(store).load(), isNull);
    });

    test('clear sonrası load → null', () async {
      final repo = SaveRepository(FakeStore());
      await repo.save(_sampleSave());
      await repo.clear();
      expect(await repo.load(), isNull);
    });
  });

  group('SharedPrefsSaveStore (shared_preferences mock)', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test('gerçek adaptör üzerinden save → load → clear', () async {
      final repo = SaveRepository(SharedPrefsSaveStore());
      expect(await repo.load(), isNull); // başlangıçta boş

      await repo.save(_sampleSave());
      final loaded = await repo.load();
      expect(loaded, isNotNull);
      expect(loaded!.resources['honor'], 2);
      expect(loaded.completedEncounters, ['ash_gate']);

      await repo.clear();
      expect(await repo.load(), isNull);
    });

    test('input.* anahtarlarına dokunmaz (sorumluluk ayrımı)', () async {
      SharedPreferences.setMockInitialValues({'input.bindings.version': 1});
      final repo = SaveRepository(SharedPrefsSaveStore());
      await repo.save(_sampleSave());
      await repo.clear();
      final prefs = await SharedPreferences.getInstance();
      // Save temizlense de input ayarı korunur.
      expect(prefs.getInt('input.bindings.version'), 1);
    });
  });
}
