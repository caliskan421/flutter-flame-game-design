# Savaş Mekaniği TODO — Genel Bakış

> **Özet:** Bu klasör, mevcut Boss Parry Arena prototipinin savaş mekaniklerini "tam
> bir oyun" seviyesine taşımak için gereken eksikleri ve önerileri **bağımsız
> sistemler** halinde toplar. Her dosya tek bir sistemi konu alır; başında bir
> **Özet** bölümü, ardından *mevcut durum → eksikler → eklenebilecekler → teknik
> dokunulacak alanlar → kabul kriterleri → öncelik* başlıkları vardır. Bu dosya
> ise tüm sistemlerin haritasını, açıkta kalan noktaları ve önerilen sırayı verir.

---

## Mevcut Sistemin Kısa Fotoğrafı

Proje, Flutter + Flame üzerinde 2D Sekiro-tarzı bir boss-parry arenasıdır. Çekirdek
oldukça olgun:

- **Oyuncu** (`lib/player.dart`): yönlü parry (üst/alt/serbest), dodge, hafif/ağır
  saldırı, posture, tempo penceresi, stun, counter/riposte, follow-up parry.
- **Boss** (`lib/boss.dart`): data-driven kombo havuzu, posture sistemi, 7 savunma
  profili, alışkanlık tabanlı adaptif seçim, pressure loop (chain/reposition/
  retreat), HP fazına göre tempo, mermi (ranged), offBalance/staggered, ölüm sekansı.
- **Veri modeli** (`lib/characters.dart`): `Beat` + `ComboPattern` + `CharacterDef`;
  6 karakter + samuray oyuncu.
- **Yardımcılar**: `fx.dart` (popup/spark/posture break), `audio.dart`, `hud.dart`,
  `input_settings.dart` (klavye + gamepad, yeniden atanabilir), `CombatMetrics`.
- **Eylem sistemi**: `TestActionSystem` (aktif) ve `NormalActionSystem` (yazılmış
  ama akışa bağlanmamış).

`COMBAT_REDESIGN_PHASES.md` dosyası Faz 0–6 planını içerir; bu plandaki bazı fazlar
(posture, defense profile, pressure loop, metrics) uygulanmış, bazıları (stamina,
window decay, bir kısım feedback) **yarım veya hiç** uygulanmamıştır.

---

## Açıkta Kalan / Yarım Kalmış Noktalar (kod kanıtlı)

Bunlar yeni özellik değil, **mevcut kodda eksik veya tamamlanmamış** noktalardır:

1. **Player stamina yok.** Redesign planında merkezî kaynak olarak geçer ama
   `Player`'da yalnız `posture` var; dodge/heavy/blok bir kaynağı tüketmiyor.
   → `01_stamina_kaynak_sistemi.md`
2. **Oyuncu blok/guard yok.** README "blok = son çare" diyor; oyuncuda yalnız
   parry/dodge/attack var, tutulan (hold) savunma yok. → `02_blok_guard_sistemi.md`
3. **Parry window decay yok.** README "spam yaparsan pencere daralır" der; uygulanmamış.
   → `03_parry_pencere_dinamigi.md`
4. **`delayed` savunma profili işlenmiyor.** `DefenseProfile.delayed` ve
   `Beat.punishesEarly` tanımlı ama `Boss._resolveContact` onu `normal` gibi ele
   alıyor; erken basış cezası gerçekte yok. → `03` ve `09`
5. **`feint` sadece kozmetik.** Aldatma beat'i parry/dodge edilince "ALDATMA" yazar
   ama erken basışı gerçekten cezalandırmaz / recovery'ye sokmaz. → `09_boss_ai_adaptasyon_sistemi.md`
6. **Heavy attack yalnız test modunda.** `tryPlayerHeavyAttack` `!testMode` ise
   erken döner (`game.dart`); gerçek maçta ağır saldırı kullanılamaz. → `05_oyuncu_saldiri_kombo_sistemi.md`
7. **`NormalActionSystem` bağlanmamış.** Tüm akış test arenası; gerçek maç/arena
   ilerleyişi yok. → `10_normal_mac_mod_akisi.md`
8. **Ayrışmamış ses.** `Sfx.postureBreak()` ve `Sfx.heavyHit()` aslında `_hit`
   çalar; `heavyHit` hiç çağrılmıyor. → `11_game_feel_feedback_sistemi.md`
9. **Kamera/screen-shake yok.** Sadece hitstop (`timeScale`) var. → `11`
10. **Gerçek i-frame yok.** Dodge, beat çözümünde `sinceDodge<=dodgePre` ile
    değerlendirilir; tüm saldırılara karşı genel bir dokunulmazlık penceresi yok.
    → `04_dodge_iframe_sistemi.md`
11. **Faz yalnız tempo ölçekler.** `phase` HP'ye göre hız değiştirir ama yeni
    moveset / faz geçiş sahnesi yok. → `08_boss_faz_gecis_sistemi.md`
12. **Deathblow/infaz yok.** Posture kırılınca büyük HP yenir ama Sekiro tarzı
    tek-tuş infaz / ekran efekti finisher'ı yok. → `06_deathblow_infaz_sistemi.md`
13. **Status efekt yok.** Ranged saldırılar yalnız HP götürür; yanma/şok/kanama yok.
    → `07_status_efekt_sistemi.md`
14. **İyileşme/consumable yok.** Oyuncu can yenileyemez (test rejeni hariç). → `12`

---

## Bağımsız Sistem Dosyaları

| # | Dosya | Sistem | Tür |
|---|-------|--------|-----|
| 01 | `01_stamina_kaynak_sistemi.md` | Oyuncu stamina/kaynak | Eksik (planlı) |
| 02 | `02_blok_guard_sistemi.md` | Oyuncu blok / guard | Eksik |
| 03 | `03_parry_pencere_dinamigi.md` | Parry penceresi & decay | Yarım |
| 04 | `04_dodge_iframe_sistemi.md` | Dodge, i-frame, mikiri | Yarım |
| 05 | `05_oyuncu_saldiri_kombo_sistemi.md` | Oyuncu saldırı & kombo | Yarım |
| 06 | `06_deathblow_infaz_sistemi.md` | Deathblow / infaz | Yeni |
| 07 | `07_status_efekt_sistemi.md` | Status efektleri | Yeni |
| 08 | `08_boss_faz_gecis_sistemi.md` | Boss faz geçişleri | Yarım |
| 09 | `09_boss_ai_adaptasyon_sistemi.md` | Boss AI & aldatma | Yarım |
| 10 | `10_normal_mac_mod_akisi.md` | Normal maç / arena akışı | Eksik |
| 11 | `11_game_feel_feedback_sistemi.md` | Game feel & feedback | Yarım |
| 12 | `12_iyilesme_kaynak_ekonomisi.md` | İyileşme / consumable | Yeni |
| 13 | `13_konum_mesafe_sistemi.md` | Konum / mesafe / hitbox | Yarım |
| 14 | `14_zorluk_erisilebilirlik.md` | Zorluk & erişilebilirlik | Yeni |
| 15 | `15_ilerleme_yetenek_sistemi.md` | İlerleme / yetenek / araç | Yeni |
| 16 | `16_test_metrik_dengeleme.md` | Metrik & dengeleme araçları | Yarım |

---

## Önerilen Uygulama Sırası

Önce hissi tamamlayan çekirdek (savaş döngüsünü "tam" hissettiren), sonra içerik
ve cila:

1. **Çekirdek tamamlama:** `01` stamina → `02` blok → `03` parry decay → `05` ağır
   saldırıyı her moda aç.
2. **Risk/ödül derinliği:** `04` i-frame/mikiri → `06` deathblow → `09` AI/aldatma.
3. **İçerik:** `08` faz geçişleri → `07` status efektleri → `13` mesafe → `15` araçlar.
4. **Oyun kabuğu:** `10` normal maç akışı → `12` iyileşme → `14` zorluk.
5. **Cila & ölçüm:** `11` game feel → `16` metrik & denge.

> **Not:** Her dosyadaki "Teknik Dokunulacak Alanlar" bölümü gerçek dosya/fonksiyon
> adlarına atıfta bulunur. Uygulamadan önce ilgili kodu tekrar doğrula; bu plan
> yazıldığı andaki yapıyı yansıtır.
