# 16 — Metrik, Dengeleme & Test Araçları

> **Özet:** `CombatMetrics` + debug overlay (` / 0 tuşu) zaten var ve maç başına
> temel sayaçları tutuyor (redesign Faz 6'nın çekirdeği uygulanmış). Ancak metrik
> kapsamı dar (yeni sistemler ölçülmüyor), tuning sayılarla değil hisle yapılıyor,
> deterministik birim testleri sınırlı ve "tek baskın strateji" otomatik tespiti
> yok. Bu dosya, yeni eklenecek sistemlerle birlikte ölçüm/denge altyapısını büyütür.

## Mevcut Durum

- `CombatMetrics` (`lib/game.dart`): `fightDuration`, `playerDamageTaken`,
  `bossDamageTaken`, `bossPostureBreaks`, `parryAttempts/Successes`,
  `dodgeAttempts/Successes`, `attackWhiffs`, `lightHits`, `heavyHits`.
- Debug overlay backquote/0 ile açılır; `hud.dart` gösterir.
- `test/` klasörü mevcut (içerik sınırlı).
- **Sorun:** `heavyHits` artmıyor (her isabet `lightHits`'e gidiyor — bkz. `05`);
  yeni sistemlerin (stamina, blok, status, deathblow) sayaçları yok.

## Eksikler / Sorunlar

- Yeni sistemler ölçülmüyor → denge "hisle" yapılacak.
- "Hangi aksiyon baskın?" otomatik özeti yok (oyuncu tek stratejiye kayıyor mu?).
- Maç sonu özeti (win/lost ekranında) metrik göstermiyor.
- Deterministik combat birim testleri az; regresyon riski.

## Eklenebilecekler (Tam Tasarım)

### Metrik kapsamını genişlet
- `lightHits`/`heavyHits` ayrımını düzelt.
- Yeni sayaçlar: `staminaEmptyDenials` (`01`), `blocks`/`guardBreaks` (`02`),
  `perfectParries`/`lateParries` (`03`), `perfectDodges`/`mikiriCounters` (`04`),
  `deathblows` (`06`), status uygulama/temizleme (`07`), `feintBaited`/
  `greedPunished` (`09`), `healsUsed`/`healsInterrupted` (`12`).
- Türetilmiş oranlar: parry başarı %, hasar kaynağı dağılımı (punish vs deathblow
  vs chip), ortalama fight süresi.

### Baskın strateji tespiti
- Maç sonunda hasarın hangi kanaldan geldiğini özetle (örn. "%80 dodge→F").
- Eşik aşılırsa debug'da uyarı: "tek strateji baskın" → tasarım sinyali.

### Maç sonu özeti
- Win/Lost ekranında (bkz. `10`) süre, parry %, posture-break sayısı, hasar dağılımı.
- No-hit / hızlı kill rozetleri (ilerleme kazanımıyla bağlanabilir — `15`).

### Deterministik testler
- Beat çözümleme (parry/dodge/wrongTool/feint/delayed) için birim testler.
- Posture → break → staggered akışı testi.
- Stamina maliyet/regen, blok→guard break, perfect/late parry testleri (yeni
  sistemler eklendikçe).
- Pencere ölçeklerinin (zorluk — `14`) doğru uygulandığının testi.

### Tuning oturumu desteği
- Çalışma zamanı tuning paneli (debug): kritik sabitleri (pencereler, hasarlar,
  regen) canlı kaydırma → playtest sırasında dengeleme.

## Teknik Dokunulacak Alanlar

- `lib/game.dart` `CombatMetrics`: yeni alanlar + `reset`; baskın strateji türetimi.
- `lib/boss.dart` / `lib/player.dart`: yeni olay kayıtlarının doğru yerlere bağlanması.
- `lib/hud.dart`: debug overlay genişletme; maç sonu özeti; (ops.) tuning paneli.
- `lib/overlays.dart`: win/lost ekranında metrik özeti.
- `test/`: yeni deterministik combat testleri.

## Kabul Kriterleri

- Her yeni savaş sistemi en az bir metrikle ölçülür.
- Maç sonunda hasarın kaynak dağılımı görülebilir; baskın strateji erken yakalanır.
- `lightHits`/`heavyHits` doğru ayrışır.
- Çekirdek combat akışları için deterministik testler geçer (regresyon koruması).

## Bağlı Sistemler
- Tüm sistemler buraya metrik besler; `10` (maç sonu özeti), `14` (ölçek testleri),
  `15` (rozet/kazanım), `09` (strateji tespiti).

## Öncelik
**Sürekli** — her yeni sistemle birlikte ilerletilmeli; tek seferlik değil.
