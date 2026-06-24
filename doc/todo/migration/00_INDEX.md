# Göç (Migration) Faz Dosyaları — İndeks & Kullanım

> **Bu klasör, `doc/architecture.md` Bölüm 13'teki A→H göç planının
> uygulanabilir iş paketlerine açılmış halidir.** Mimari doküman "neye doğru"
> sorusunu; bu dosyalar "şimdi tam olarak ne yapılacak" sorusunu cevaplar.

---

## 0. Claude Code bu dosyaları nasıl kullanır? (ÖNEMLİ)

Bir faz dosyası Claude Code'a referans olarak verildiğinde (örn. *"`doc/todo/migration/FAZ_B_event_ve_saf_kural.md` dosyasını uygula"*), o dosya **tek başına yeterli iş emridir.** Akış:

1. **Önce** bu indeksin §3 (Global değişmezler) ve §4 (Bağımlılık) bölümünü oku — fazın ön-koşulu sağlanmış mı kontrol et.
2. Faz dosyasındaki **§2 Kapsam (DAHİL/HARİÇ)** sınırının dışına çıkma. "Bonus" iş yapma.
3. **§4 Görev checklist**'ini sırayla uygula; her adımda gerçek sembol/dosya adlarını kullan (faz dosyasında verilmiştir).
4. Bitince **§5 Kabul kriterleri** + **§7 Doğrulama komutları**'nı çalıştır; hepsi yeşil olmadan fazı "bitti" sayma.
5. Davranış değişmemesi gereken fazlarda (A, B, C, D, F) **test sandbox davranışı birebir korunmalı** (§3).

> Bir faz dosyası, gerçeğe aykırı bir referans içeriyorsa (dosya/fonksiyon adı değişmişse) **dur ve önce dosyayı güncelle**, körlemesine uygulama. Bu dosyalar yaşayan plandır.

---

## 1. Faz dosyaları

| Dosya | Faz | Bir cümlede |
|---|---|---|
| [`FAZ_A_mimari_temizlik.md`](FAZ_A_mimari_temizlik.md) | **A** | Davranış değişmeden sorumlulukları ayır: `CombatMetrics` + FX/zaman helper'larını `game.dart` dışına al, `GameSession` iskeleti, intro cue'larını veriye taşı. |
| [`FAZ_B_event_ve_saf_kural.md`](FAZ_B_event_ve_saf_kural.md) | **B** | `EventBus` + `CombatEvent`; combat kararının `Sfx`/`spawnPopup` çağırması yerine event yayması; `CombatResolver`'ı saf fonksiyona çekmenin ilk dilimi. |
| [`FAZ_C_player_action_timeline.md`](FAZ_C_player_action_timeline.md) | **C** | `ActionTimeline` + `PlayerMoveDef`; parry/dodge/light/heavy sürelerini veriden okut; sprite'ı timeline ilerleyişine bağla. |
| [`FAZ_D_animation_binding.md`](FAZ_D_animation_binding.md) | **D** | `AnimationBinding` + `markerFrames`; `sprite_strip.dart` binding'i okusun; contact/telegraph kareleri sanatçı verisi olsun. |
| [`FAZ_E_normal_mac_akisi.md`](FAZ_E_normal_mac_akisi.md) | **E** | `NormalActionSystem`'i gerçek (ölümlü) maça bağla; boss seçim + win/loss/retry/next akışı; sandbox aynen korunur. |
| [`FAZ_F_boss_ayristirma.md`](FAZ_F_boss_ayristirma.md) | **F** | `boss.dart` (1627 sat.) → `boss_brain` / `combat_resolver` / `state_machine` / `posture_system` / `deathblow_controller` / `boss_view`'a böl. |
| [`FAZ_G_rpg_dikey_kesit.md`](FAZ_G_rpg_dikey_kesit.md) | **G** | `ScenarioState` + `EncounterDef`/`DialogueNodeDef`/`ChoiceDef`/`DiceCheckDef`; tek encounter uçtan uca; combat sonucu flag üretir. |
| [`FAZ_H_save_load_progression.md`](FAZ_H_save_load_progression.md) | **H** | `SaveState` + `shared_preferences` ile JSON kalıcılık; flag/resource/ilerleme kaydı. |

---

## 2. Bağımlılık grafiği (sıralı omurga + paralel kollar)

```text
A (mimari temizlik)
└─► B (event + saf kural)
     ├─► C (player action timeline) ─┐
     ├─► D (animation binding)  ◄─────┤  (C ∥ D paralel; D, C'nin timeline'ını okur ama ayrı dosyalar)
     ├─► E (normal maç akışı)         │  (A+B üstüne; C/D ile paralel ilerleyebilir)
     └─► F (boss ayrıştırma)          │  (B şart; C/D bittiyse daha temiz)
                                      ▼
                       E + F ──► G (RPG dikey kesit) ──► H (save/load)
```

**Kesin kurallar:**
- **A → B** sıralı (temel atılmadan event/saf kural anlamsız).
- **C ∥ D ∥ E** B bittikten sonra paralel yürüyebilir (farklı dosyalara dokunurlar).
- **F** B'yi şart koşar; C ve D bittiyse `boss_view` ayrımı çok daha kolay olur (önerilen sıra: F'yi C/D sonrası yap).
- **G** hem E (gerçek maç akışı) hem F (temiz boss) bitmeden başlamaz.
- **H** G'den sonra (kaydedilecek kalıcı durum G'de doğar).

**Önerilen tek-kişilik sıralı yürütüş:** A → B → C → D → E → F → G → H.
**Paralel ekip varsa:** A → B; sonra {C, D, E} paralel; ardından F; sonra G → H.

---

## 3. Global değişmezler (HER faz için geçerli — Definition of Done'ın parçası)

Bir faz ancak şunların **hepsi** sağlanırsa "bitti" sayılır:

1. **`flutter analyze` temiz** (yeni uyarı/eklenmedi).
2. **`flutter test` tamamen yeşil** — mevcut testler kırılmaz.
3. **Test sandbox davranışı korunur:** `TestActionSystem` (realMatch=false) modundaki eğitim/pratik davranışı (ölümsüzlük, yerinde döngü, sınırsız stamina) hiçbir fazda bozulmaz. Yeni combat ayarı eklenecekse `ArenaActionSystem`'e **default getter** olarak eklenir; sandbox muaf kalır (proje hafıza kuralı: *"Combat tuning via action system"*).
4. **Davranış-koruyan fazlarda (A, B, C, D, F)** oyuncunun gördüğü davranış birebir aynı kalır — bu fazlar refactor'dur, özellik eklemez.
5. **Tek-yön bağımlılık korunur:** alt katman üstü import etmez (`combat/rules`, `domain` → `game.dart`/Flame'e bağlanmaz). Yeni saf Dart kodu `Sfx`/`spawnPopup`/Flame çağırmaz; sonuç döner ya da `CombatEvent` yayar.
6. **Her faz çalışan bir oyun bırakır** (derlenir + açılır + oynanır).

---

## 4. Hedef klasör yerleşimi (yeni kod nereye gider — `architecture.md` §10)

Göç kademeli; tek seferde taşıma yok. Ama **yeni kod** doğru katmana yazılır:

```
lib/
  app/      main.dart · game.dart (incelen orkestratör) · flow/encounter_runner.dart
  core/     event_bus.dart · time_fx.dart · rng.dart · result.dart · locator.dart
  domain/   game_session.dart · scenario_state.dart · inventory.dart · save_state.dart
  combat/
    data/   characters.dart · move_def.dart · action_timeline.dart
    rules/  combat_resolver.dart · parry_rules.dart · hitbox_model.dart · combat_event.dart
    ai/     boss_brain.dart
    sim/    player.dart · boss.dart · boss_state_machine.dart · posture_system.dart
            deathblow_controller.dart · projectile.dart
    config/ action_system.dart (+ test/normal)
  content/  encounters/ · dialogues/ · dice/    (içerik = veri, kod değil)
  presentation/
    hud.dart · overlays/ · fx.dart · audio.dart · sprite_strip.dart
    animation_binding.dart · boss_view.dart · player_view.dart
    input_settings.dart · theme.dart
```

> Mevcut dosyalar `lib/` kökünde düz duruyor. Klasöre taşıma **opsiyonel ve kademeli**; bir fazın zorunlu çıktısı değil. Zorunlu olan: yeni dosyanın hangi katmana ait olduğunu bilmek ve import yönünü bozmamak. Toplu taşıma yapılırsa import yolları + `package:boss_parry_arena/...` referansları güncellenmeli.

---

## 5. Konvansiyonlar

- **Dil:** Dokümanlar ve kullanıcıya görünen metinler Türkçe; kod/sembol adları İngilizce (mevcut desen).
- **Paket importu:** `package:boss_parry_arena/...` (pubspec `name: boss_parry_arena`).
- **Dart sürümü:** SDK `^3.10.8` → `sealed class`, `enum` + pattern matching serbest.
- **Commit:** Her faz **kendi commit'i (veya küçük commit serisi)**; mesaj fazı belirtir, sonunda:
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- **Branch:** `main` üzerinde doğrudan çalışma; faz başına `migration/faz-x-...` dalı önerilir (kullanıcı isterse).
- **Test:** Yeni saf Dart birimi = yeni `test/*.dart`. Saf fonksiyonlar Flame/Flutter olmadan test edilebilir olmalı.

---

## 6. Durum takibi

| Faz | Durum | Not |
|---|---|---|
| A | ✅ Bitti | CombatMetrics→domain, TimeFx→core, GameSession iskeleti, intro cue'ları→content. analyze temiz, testler yeşil. |
| B | ✅ Bitti | EventBus+CombatEvent+CombatPresenter; boss.dart event yayar (Sfx/popup/metrics/request* → bus); CombatResolver saf temas kararı. analyze temiz, testler yeşil. |
| C | ✅ Bitti | ActionTimeline+PlayerMoveDef; parry/dodge/light/heavy süreleri veriden (tek kaynak k* sabitleri); _atkTotal=timeline.duration, dodgeInvulnerableAt=isIn(iframe). Davranış birebir. analyze temiz, 100 test yeşil. Not: low-parry penceresi ayrı model olarak Faz D'ye bırakıldı. |
| D | ⬜ Başlamadı | B'ye bağlı (C ile paralel) |
| E | ⬜ Başlamadı | A+B'ye bağlı |
| F | ⬜ Başlamadı | B'ye bağlı (C/D sonrası önerilir) |
| G | ⬜ Başlamadı | E+F'ye bağlı |
| H | ⬜ Başlamadı | G'ye bağlı |

> Bir faz bitince bu tabloyu (`⬜→✅`) ve ilgili faz dosyasının başındaki durum satırını güncelle.

---

## 7. Hızlı doğrulama komutları (her faz sonunda)

```bash
flutter analyze
flutter test
# elle duman testi:
flutter run -d macos   # veya hedef platform; oyun açılıp test arena oynanmalı
```
