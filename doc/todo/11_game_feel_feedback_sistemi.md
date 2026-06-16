# 11 — Game Feel & Feedback Sistemi

> **Özet:** README'nin "Juice" ve "görsel/işitsel kontrast" ilkeleri ile redesign
> Faz 5 burada toplanır. Hitstop, spark, popup, posture-break efekti zaten var;
> ama kamera/screen-shake yok, sesler ayrışmamış (`postureBreak`/`heavyHit` aslında
> `hit` çalıyor, `heavyHit` hiç çağrılmıyor), perfect/late ayrımı feedback'e
> yansımıyor ve afterimage/dust trail eksik. Bu dosya temas hissini tamamlar.

## Mevcut Durum

- **Hitstop:** `game.requestHitstop` + `update`'te `timeScale 0.06` → çalışıyor.
- **FX:** `Popup`, `ComboText`, `Spark`, `PostureBreakFx` (`lib/fx.dart`).
- **Ses:** `Sfx.parry/dodge/hit/block/whiff/swordDrop`; `postureBreak()` ve
  `heavyHit()` **aslında `_hit` çalıyor**; `heavyHit` hiç çağrılmıyor.
- **Görsel:** parry ring, dodge streak, telegraf pill, açık marker.

## Eksikler / Sorunlar

- **Kamera/screen-shake yok** (yalnız zaman ölçeği). README "ekranın hafifçe
  sallanması" ister; özellikle heavy isabet ve posture-break için eksik.
- **Ayrışmamış ses:** posture-break, heavy hit, perfect parry hep aynı `hit`/`parry`.
- **Perfect/late feedback yok:** `03`/`04`'teki kalite ayrımı görsel/işitsel değil.
- **Afterimage / dust trail yok** (dodge için yalnız basit streak).
- **Faz geçiş / infaz stagingi yok** (bkz. `06`, `08`).
- **Popup okunabilirliği:** yoğun anlarda üst üste binebilir (öncelik/sıralama yok).

## Eklenebilecekler (Tam Tasarım)

### Kamera & screen-shake
- Hafif kamera shake bileşeni (genlik + sönüm): heavy isabet (küçük), posture-break
  (orta), deathblow (büyük). Flame `CameraComponent` / dünya offset üzerinden.
- Aşırıya kaçmadan; okunabilirliği bozmayan eşikler (bkz. Riskler).

### Ses ayrıştırma
- Gerçek `postureBreak()` ve `heavyHit()` SFX'leri (ayrı dosyalar) ekle ve çağır.
- `parryPerfect()` vs `parryLate()` (bkz. `03`).
- Blok için ayrı tok metal sesi (bkz. `02`).
- Dinamik müzik: combat yoğunluğuna / faza göre katman (bkz. `08`).

### Görsel kalite katmanları
- Perfect parry: büyük parlak sarı/turuncu spark + daha uzun hitstop.
- Dodge: afterimage/ghosting trail (özellikle perfect dodge).
- Heavy isabet: knockback + toz + büyük popup.
- Deathblow: ekran kırmızı vinyet + slow-mo (bkz. `06`).

### Popup yönetimi
- Aynı anda çok popup olunca dikey istifleme/öncelik; kritik bilgiler (DENGE KIRILDI,
  İNFAZ) önde.

### Hitstop tuning
- Aksiyona göre süre tablosu (perfect parry ~50–90ms, heavy ~140ms, deathblow uzun);
  ardışık hitstop birikmesini sınırla.

## Teknik Dokunulacak Alanlar

- `lib/game.dart`: screen-shake state + `update`'te uygulama; hitstop tablosu;
  slow-mo (deathblow) için ayrı zaman ölçeği yolu.
- `lib/fx.dart`: afterimage, dust, perfect spark, kırmızı vinyet bileşenleri.
- `lib/audio.dart`: yeni SFX havuzları + ayrışmış çağrılar; dinamik müzik.
- `lib/boss.dart` / `lib/player.dart`: doğru feedback çağrılarının doğru yerlere
  bağlanması (perfect/late, heavy, posture-break, deathblow).
- `lib/hud.dart` / `lib/fx.dart`: popup istifleme/öncelik.

## Kabul Kriterleri

- Perfect parry, late parry, blok, heavy isabet, posture-break ve deathblow
  birbirinden **ses ve görsel olarak net ayrışır** (gözü kapalı ayırt edilebilir).
- `Sfx.postureBreak()`/`heavyHit()` gerçek ayrı sesler çalar ve çağrılır.
- Screen-shake var ama okunabilirliği bozmuyor; ayarlanabilir/kapatılabilir (bkz. `14`).
- Yoğun anlarda popup'lar üst üste binip bilgiyi kaybetmiyor.

## Riskler
- Fazla shake/hitstop akıcılığı ve okunabilirliği bozar → eşikleri muhafazakâr tut,
  erişilebilirlik ayarıyla kıs/kapat (bkz. `14`).
- Efektler mekanik sorunları **maskelemek** için kullanılmamalı.

## Bağlı Sistemler
- `03`, `04`, `06`, `08` (hepsi feedback üretir), `14_zorluk_erisilebilirlik`
  (shake/flash ayarları), `16` (tuning ölçümü).

## Öncelik
**Orta** — mekanikler oturduktan sonra; ama düşük maliyetli kazançlar (ses
ayrıştırma) erken yapılabilir.
