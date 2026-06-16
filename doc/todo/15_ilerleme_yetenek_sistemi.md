# 15 — İlerleme / Yetenek / Özel Araç Sistemi

> **Özet:** Oyuncunun savaş repertuarı sabit (parry/dodge/light/heavy + follow-up).
> Sekiro'nun "prosthetic tools" ve yetenek ağacı gibi, maçlar arası kazanılan ve
> savaşa yeni mekanik/seçenek ekleyen bir ilerleme sistemi yok. Bu dosya, savaş
> derinliğini içerikle büyüten bir yetenek/özel araç katmanını tasarlar. (Salt
> savaş odaklı: ekonomi/hikaye değil, **savaşta kullanılan** yetenekler.)

## Mevcut Durum

- Oyuncu yetenek seti `Player` içinde sabit kodlanmış: parry (yönlü), dodge,
  light/heavy attack, counter/riposte, follow-up parry.
- `CharacterDef` data-driven ama yalnız boss çeşitliliği için; oyuncunun *kazanılan*
  yeteneği yok.
- Arena ilerleyişi yok (bkz. `10`) → kazanım bağlamı da yok.

## Eksikler / Sorunlar

- Tekrar oynanabilirlik düşük: her maç aynı araç setiyle.
- "Bu boss'a karşı şu aracı seçeyim" gibi taktiksel hazırlık kararı yok.
- Yetenekli oyunun kalıcı ödülü (yeni mekanik açma) yok.

## Eklenebilecekler (Tam Tasarım)

### Özel araçlar (aktif yetenekler)
- Cooldown veya kaynak (stamina/şarj) ile kullanılan aktif savaş araçları, örn:
  - **Atış/uzak araç:** boss'un ranged baskısını kıran kısa menzilli karşılık.
  - **Sersemletici:** kısa süreli boss posture açığı (bir slotluk, cooldown'lu).
  - **Savuşturma artırıcı:** kısa süre parry penceresini genişleten buff.
- Aynı anda 1–2 araç "donatılır"; maç öncesi seçilir (boss'a göre hazırlık).

### Pasif yetenekler (yetenek ağacı)
- Kalıcı küçük iyileştirmeler: +parry penceresi, +stamina regen, +deathblow hasarı,
  perfect-dodge ödülü artışı, fazladan şifa şarjı (bkz. `12`).
- Yetenek puanı boss yenerek / metriklerle (No-hit, fast-kill) kazanılır.

### Donanım / stance (opsiyonel/ileri)
- Saldırı stance'leri (hız vs hasar) — light/heavy ekonomisini değiştiren modlar.

### Hazırlık ekranı
- Maç öncesi araç/pasif seçimi (mevcut `testSelect`/seçim UI deseni temel alınabilir).

## Teknik Dokunulacak Alanlar

- Yeni `lib/abilities.dart`: `Ability` (aktif/pasif) tanımları, cooldown/kaynak,
  donatım slotları.
- `lib/player.dart`: donatılı araçların durumu; aktivasyon input'u; pasiflerin
  parametrelere (pencere, regen, hasar) uygulanması.
- `lib/game.dart` + `lib/input_settings.dart`: araç aktivasyon aksiyon(lar)ı + binding.
- `lib/boss.dart`: araç etkilerine tepki (örn. sersemletici → posture açığı).
- `lib/overlays.dart`: hazırlık/yetenek ekranı; ilerleme kaydı.
- Kalıcılık: yetenek puanı/unlock kaydı (InputSettings kayıt deseni örnek).
- `lib/hud.dart`: araç cooldown/şarj göstergesi.

## Kabul Kriterleri

- Oyuncu en az 1–2 aktif araç donatıp savaşta kullanabilir.
- Pasif yetenekler savaş parametrelerini ölçülebilir biçimde değiştirir.
- Yetenekler maç ilerleyişiyle (boss yenme/metrik) kazanılır.
- Araçlar dengeli: hiçbiri çekirdek parry/dodge döngüsünü gereksiz kılmaz.

## Bağlı Sistemler
- `10_normal_mac_mod_akisi` (kazanım bağlamı), `01` (kaynak maliyeti),
  `12` (şifa kapasitesi), `06` (deathblow hasar pasifi), `16` (kazanım metrikleri).

## Öncelik
**Düşük** — tekrar oynanabilirlik/uzun vade için; çekirdek ve mod kabuğu sonrası.
