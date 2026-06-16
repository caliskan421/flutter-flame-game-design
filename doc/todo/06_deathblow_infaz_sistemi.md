# 06 — Deathblow / İnfaz Sistemi

> **Özet:** README'nin "zirve noktası" olarak tanımladığı mekanik: posture (denge)
> patladığında ekranın kırmızıya büründüğü, zamanın yavaşladığı ve tek tuşla
> düşmanın infaz edildiği **Deathblow**. Mevcut sistemde posture kırılınca boss
> `staggered` olur ve oyuncu büyük HP vurur, ama özel bir "infaz" anı/finisher
> yoktur. Bu dosya posture-break ödülünü Sekiro-vari bir doruk anına dönüştürür.

## Mevcut Durum

- `Boss.breakPosture()`: posture 0 → `staggered` durumu (`postureBreakDur = 1.15s`),
  "DENGE KIRILDI" yazısı, `spawnPostureBreak`, `Sfx.hit`, kısa hitstop (0.13).
- `staggered` iken `receivePlayerAttack` büyük HP verir (test: heavy 40 / light 10;
  gerçek: `attackHpStagger=18 + tempo`).
- Stagger süresi bitince posture full'e döner, boss pressure'a geçer.
- **Yok:** tek-tuş özel infaz, ekran kırmızı/slow-mo doruk efekti, infaza özel
  animasyon/ses, HP eşiğine bağlı "öldürücü infaz".

## Eksikler / Sorunlar

- Posture break ödülü "biraz daha HP vur" ile sınırlı; doruk hissi (dopamin anı) zayıf.
- Sekiro'daki "can %80 olsa bile denge patlarsa infaz" çekirdek fantezisi yok →
  "dengeyi patlatmak yetenek işidir" ödülü eksik.
- `Sfx.postureBreak()` tanımlı ama `breakPosture` `Sfx.hit()` çağırıyor (ayrışmamış).

## Eklenebilecekler (Tam Tasarım)

### Deathblow penceresi
- `staggered` girince boss'un üstünde belirgin **"İNFAZ ⟶ F"** işareti (mevcut
  "VUR F" marker'ından ayrı, daha güçlü).
- Bu pencerede yapılan saldırı normal HP yerine bir **deathblow** tetikler:
  - kısa slow-mo + ekran kırmızı vinyet,
  - özel infaz animasyonu (oyuncu + boss),
  - büyük/öldürücü hasar (eşik altındaysa direkt öldürür).

### Deathblow sayacı (çok-canlı boss)
- Sekiro mantığı: bazı bosslar birden çok deathblow ister. `Boss.deathblowsRequired`
  (örn. 2). Her infaz bir HP "bar segmenti" siler; son segmentte ölür.
- HP düşükken posture daha kırılgan → "dengeyi patlat, infazla bitir" akışı.

### Öldürücü infaz eşiği
- Boss HP'si `executeThreshold` (örn. %25) altındayken posture kırılırsa infaz
  **anında öldürür** → riskli ama yetenekli oyuncuyu ödüllendirir.

### Feedback (README "Altın Kural 3")
- Ekran kırmızı tonu, zaman yavaşlaması, ağır ses, ardından sessizlik → doruk anı.

## Teknik Dokunulacak Alanlar

- `lib/boss.dart`
  - `breakPosture`: `Sfx.postureBreak()` kullan (hit yerine).
  - `staggered` içinde "deathblow available" bayrağı + marker.
  - `receivePlayerAttack` `staggered` dalı: deathblow tetikle (normal HP yerine
    finisher). `deathblowsRequired` ve eşik mantığı.
  - infaz tetikleyince `die()` veya segment azalt.
- `lib/player.dart`: infaz animasyon durumu (`riposte`/yeni `execute` state).
- `lib/fx.dart`: ekran kırmızı vinyet + büyük posture-break varyantı.
- `lib/game.dart`: slow-mo (mevcut `requestHitstop`/`timeScale` mantığını daha uzun
  bir "execution slowmo" için genişlet).
- `lib/audio.dart`: ayrışmış `postureBreak()` ve infaz sesi.
- `lib/hud.dart`: çok-deathblow için HP bar segmentleri.

## Kabul Kriterleri

- Posture break, tek-tuş özel bir infaz anına dönüşür (slow-mo + kırmızı + ses).
- Düşük HP'de posture break öldürücü olur; yüksek HP'de büyük hasar/segment siler.
- `Sfx.postureBreak()` gerçekten ayrı bir ses çalar.
- "Dengeyi patlat → infazla bitir" akışı oyuncuya net hissedilir.

## Bağlı Sistemler
- `03_parry_pencere_dinamigi` (posture'ı kıran asıl araç), `05` (finisher),
  `08_boss_faz_gecis_sistemi` (segment/faz), `11_game_feel_feedback_sistemi`.

## Öncelik
**Orta-Yüksek** — savaşın duygusal doruğu; posture sistemi olgun olduğu için
görece düşük maliyetle büyük his kazancı.
