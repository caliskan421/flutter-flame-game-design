// ============================================================================
//  HUD  —  SAĞ KENAR ÇUBUĞU  ('elements' parşömen/ahşap character_panel kartı)
// ----------------------------------------------------------------------------
//  Seçilen boss'un portresini, adını/sınıfını, kombo desenini (chip'ler;
//  güncel beat + mustDefend vurgulanır), canlı DURUM bloğunu ve BOSS/SEN HP
//  barlarını gösterir. Tümü yeşil/parşömen 'elements' görünümünde.
//
//  Yerleşim/ölçek yaklaşımı orijinal Hud'dan alındı (_naturalH ölçek hilesi)
//  ama renkler ve kart görünümü 'elements' kitine göre yeniden boyandı.
// ============================================================================

import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'characters.dart';
import 'game.dart';
import 'theme.dart';

class Hud extends PositionComponent with HasGameReference<BossArenaGame> {
  Hud() : super(priority: 100);

  // --- METİN STİLLERİ (parşömen üstü koyu metin) ---
  final _kicker = TextPaint(
    style: const TextStyle(
      color: kUiWood,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 4,
    ),
  );
  final _title = TextPaint(
    style: const TextStyle(
      color: kTextDark,
      fontSize: 21,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.5,
    ),
  );
  final _classTag = TextPaint(
    style: const TextStyle(
      color: kUiGreenDark,
      fontSize: 12,
      fontWeight: FontWeight.w800,
      letterSpacing: 3,
    ),
  );
  final _section = TextPaint(
    style: const TextStyle(
      color: kUiWood,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 3,
    ),
  );
  final _comboTitle = TextPaint(
    style: const TextStyle(
      color: kTextDark,
      fontSize: 14,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.5,
    ),
  );
  final _desc = TextPaint(
    style: const TextStyle(color: kUiWoodDark, fontSize: 11.5, height: 1.2),
  );
  final _label = TextPaint(
    style: const TextStyle(
      color: kTextDark,
      fontSize: 13,
      fontWeight: FontWeight.w700,
    ),
  );
  final _statusVal = TextPaint(
    style: const TextStyle(
      color: kUiGreenDark,
      fontSize: 15,
      fontWeight: FontWeight.w800,
    ),
  );
  final _statusOff = TextPaint(
    style: const TextStyle(
      color: kUiWoodDark,
      fontSize: 15,
      fontWeight: FontWeight.w700,
    ),
  );
  final _hpNum = TextPaint(
    style: const TextStyle(
      color: kTextDark,
      fontSize: 13,
      fontWeight: FontWeight.w800,
    ),
  );
  final _foot = TextPaint(
    style: const TextStyle(
      color: kUiWoodDark,
      fontSize: 11,
      letterSpacing: 0.5,
      fontWeight: FontWeight.w700,
    ),
  );
  final _placeholder = TextPaint(
    style: const TextStyle(
      color: kUiParchEdge,
      fontSize: 18,
      fontWeight: FontWeight.w800,
      letterSpacing: 4,
    ),
  );

  // Tüm içeriğin sığdığı tasarım yüksekliği. Panel bundan kısaysa içerik bu
  // orana göre küçültülür (üst üste binmeyi önler).
  static const double _naturalH = 820;

  @override
  void render(Canvas canvas) {
    final s = game.sidebarRect;
    if (s.isEmpty) return;

    // --- KART: ahşap dış kenar + parşömen zemin (PixelFrame görünümü) ---
    _drawCard(canvas, s);

    const double pad = 22;
    final double scale = min(1.0, s.height / _naturalH);

    canvas.save();
    canvas.translate(s.left, s.top);
    canvas.scale(scale);

    final double bottomCoord = s.height / scale;
    final double x = pad;
    final double w = s.width / scale - pad * 2;

    final def = game.selectedChar;
    if (def == null) {
      _renderPlaceholder(canvas, x, w, bottomCoord);
      canvas.restore();
      return;
    }

    double y = pad;

    // --- BAŞLIK: kicker + isim + sınıf etiketi ---
    _kicker.render(canvas, 'RAKİP', Vector2(x, y));
    y += 16;
    _title.render(canvas, def.name, Vector2(x, y));
    y += 28;
    _classTag.render(canvas, _classTr(def.cls), Vector2(x, y));
    y += 24;
    _divider(canvas, x, y, w);
    y += 18;

    // --- PORTRE (halka içinde) + kombo başlığı/blurb ---
    const double portraitSize = 88;
    _drawPortrait(canvas, x, y, portraitSize);
    final double tx = x + portraitSize + 16;
    final double tw = w - portraitSize - 16;
    _section.render(canvas, 'KOMBO', Vector2(tx, y + 4));
    _comboTitle.render(canvas, def.title, Vector2(tx, y + 22));
    _wrapText(canvas, _desc, def.blurb, tx, y + 42, tw, 3);
    y += portraitSize + 16;

    _divider(canvas, x, y, w);
    y += 18;

    // --- KOMBO DESENİ: beat chip satırı (oyun sırasında AKTİF kombo) ---
    _section.render(canvas, 'DESEN', Vector2(x, y));
    y += 20;
    final beats = game.boss?.activeBeats ?? def.pattern.beats;
    y = _drawBeatChips(canvas, x, y, w, beats);
    y += 8;
    _divider(canvas, x, y, w);
    y += 18;

    // --- DURUM canlı bloğu ---
    _section.render(canvas, 'DURUM', Vector2(x, y));
    y += 22;

    final boss = game.boss;
    _label.render(canvas, 'Boss', Vector2(x, y));
    _statusVal.render(
      canvas,
      boss?.phaseLabelTr ?? '—',
      Vector2(x + 86, y - 1),
    );
    y += 24;

    _label.render(canvas, 'Parry', Vector2(x, y));
    final parrying = game.player.isParrying;
    (parrying ? _statusVal : _statusOff).render(
      canvas,
      parrying ? 'AÇIK' : 'kapalı',
      Vector2(x + 86, y - 1),
    );
    y += 24;

    _label.render(canvas, 'Dodge', Vector2(x, y));
    final dodging = game.player.isDodging;
    (dodging ? _statusVal : _statusOff).render(
      canvas,
      dodging ? 'AÇIK' : 'kapalı',
      Vector2(x + 86, y - 1),
    );
    y += 24;

    _label.render(canvas, 'Kombo', Vector2(x, y));
    final total = beats.length;
    final stored = (boss?.storedCombo ?? 0).clamp(0, total);
    (stored > 0 ? _statusVal : _statusOff).render(
      canvas,
      '$stored / $total',
      Vector2(x + 86, y - 1),
    );
    y += 28;

    // --- BARLAR: panel tabanına sabit (BOSS HP, BOSS DENGE, SEN HP) ---
    final double barsY = max(y + 16, bottomCoord - pad - 136);
    _divider(canvas, x, barsY - 14, w);
    _hpBar(
      canvas,
      x,
      barsY,
      w,
      'BOSS',
      kBarRed,
      boss?.health ?? 100,
      boss?.displayHealth ?? 100,
    );
    _hpBar(
      canvas,
      x,
      barsY + 40,
      w,
      'DENGE',
      kBarBlue,
      boss?.posture.round() ?? 100,
      boss?.displayPosture ?? 100,
      maxVal: (boss?.maxPosture ?? 100).toDouble(),
    );
    _hpBar(
      canvas,
      x,
      barsY + 80,
      w,
      'SEN',
      kBarGreen,
      game.player.health,
      game.player.displayHealth,
    );

    _foot.render(
      canvas,
      'SPACE Parry · SHIFT Kaç (kırmızı) · F Vur',
      Vector2(x, bottomCoord - pad - 2),
    );

    canvas.restore();

    if (game.debug) _renderDebug(canvas);
  }

  // --------------------------------------------------------------------------
  //  KART ARKA PLANI  —  ahşap kenar + parşömen zemin (PixelFrame'e benzer)
  // --------------------------------------------------------------------------
  void _drawCard(Canvas canvas, Rect s) {
    final outer = RRect.fromRectAndRadius(s, const Radius.circular(2));
    canvas.drawRRect(outer, Paint()..color = kUiWoodDark);
    final inner = RRect.fromRectAndRadius(
      s.deflate(4),
      const Radius.circular(2),
    );
    canvas.drawRRect(inner, Paint()..color = kUiParchment);
    canvas.drawRRect(
      inner,
      Paint()
        ..color = kUiWood
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  void _renderPlaceholder(
    Canvas canvas,
    double x,
    double w,
    double bottomCoord,
  ) {
    final cx = x + w / 2;
    final cy = bottomCoord / 2;
    // hayalet kart silüeti
    final box = Rect.fromCenter(center: Offset(cx, cy), width: 92, height: 92);
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(2)),
      Paint()
        ..color = kUiParchEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    _placeholder.render(canvas, 'RAKİP SEÇ', Vector2(cx - 56, cy + 64));
  }

  // --------------------------------------------------------------------------
  //  PORTRE  —  boss idle karesini (Sprite) bir halka içinde çiz
  // --------------------------------------------------------------------------
  void _drawPortrait(Canvas canvas, double x, double y, double size) {
    final rect = Rect.fromLTWH(x, y, size, size);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(2));
    // halka zemini (parşömen kenarı) + ahşap çerçeve
    canvas.drawRRect(rr, Paint()..color = kUiParchEdge);

    final sprite = game.boss?.portraitSprite;
    if (sprite != null) {
      canvas.save();
      canvas.clipRRect(rr);
      // kareyi en-boy koruyarak içe sığdır (contain), hafif iç boşlukla
      final src = sprite.srcSize;
      final aspect = src.x / src.y;
      double dw = size - 12, dh = size - 12;
      if (aspect >= 1) {
        dh = dw / aspect;
      } else {
        dw = dh * aspect;
      }
      final dx = x + (size - dw) / 2;
      final dy = y + (size - dh) / 2;
      sprite.render(canvas, position: Vector2(dx, dy), size: Vector2(dw, dh));
      canvas.restore();
    }

    // dış ahşap çerçeve + yeşil iç vurgu
    canvas.drawRRect(
      rr,
      Paint()
        ..color = kUiWood
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(3), const Radius.circular(2)),
      Paint()
        ..color = kUiGreenDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  // --------------------------------------------------------------------------
  //  BEAT CHIP'LERİ
  //    meleeLight = küçük dolu kare,  meleeHeavy = büyük dolu kare,
  //    ranged     = üçgen,            feint      = boş (hollow) kare
  //    mustDefend = etrafına halka,   currentBeatIndex = vurgulu (yeşil)
  // --------------------------------------------------------------------------
  double _drawBeatChips(
    Canvas canvas,
    double x,
    double y,
    double w,
    List<Beat> beats,
  ) {
    const double cell = 36; // chip hücre genişliği
    const double gap = 10;
    final int cur = game.boss?.currentBeatIndex ?? -1;

    double cx = x;
    for (int i = 0; i < beats.length; i++) {
      if (cx + cell > x + w) {
        // satır taşarsa alt satıra geç
        cx = x;
        y += cell + gap;
      }
      final active = i == cur;
      _drawChip(canvas, cx, y, cell, beats[i], active);
      cx += cell + gap;
    }
    return y + cell;
  }

  void _drawChip(
    Canvas canvas,
    double x,
    double y,
    double cell,
    Beat beat,
    bool active,
  ) {
    final center = Offset(x + cell / 2, y + cell / 2);

    // chip taban kutucuğu (her zaman pixel kare zemin)
    final base = Rect.fromLTWH(x, y, cell, cell);
    final baseRR = RRect.fromRectAndRadius(base, const Radius.circular(2));
    canvas.drawRRect(
      baseRR,
      Paint()..color = active ? kUiGreenLight : kUiParchEdge,
    );
    canvas.drawRRect(
      baseRR,
      Paint()
        ..color = active ? kUiGreenDark : kUiWood
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 3 : 2,
    );

    final Color ink = active ? kUiGreenDark : kUiWoodDark;
    final fill = Paint()..color = ink;
    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    switch (beat.kind) {
      case BeatKind.meleeLight:
        final r = Rect.fromCenter(center: center, width: 12, height: 12);
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(1)),
          fill,
        );
        break;
      case BeatKind.meleeHeavy:
        final r = Rect.fromCenter(center: center, width: 20, height: 20);
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(1)),
          fill,
        );
        break;
      case BeatKind.ranged:
        // yukarı bakan üçgen
        final path = Path()
          ..moveTo(center.dx, center.dy - 10)
          ..lineTo(center.dx + 10, center.dy + 8)
          ..lineTo(center.dx - 10, center.dy + 8)
          ..close();
        canvas.drawPath(path, fill);
        break;
      case BeatKind.feint:
        // boş (hollow) kare
        final r = Rect.fromCenter(center: center, width: 16, height: 16);
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(1)),
          stroke,
        );
        break;
    }

    // savunma profili: alt kenarda renkli şerit (telegraf desteği)
    final pc = _profileColor(beat.defense);
    if (pc != null) {
      canvas.drawRect(
        Rect.fromLTWH(x + 3, y + cell - 5, cell - 6, 3),
        Paint()..color = pc,
      );
    }

    // mustDefend → kırmızımsı uyarı halkası + üst köşede yıldız
    if (beat.mustDefend) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(base.inflate(3), const Radius.circular(3)),
        Paint()
          ..color = kBarRed
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  // Savunma profili → chip alt şeridi rengi. SADE MODEL: yalnız KIRMIZI
  // (guardBreak = kaç) işaretlenir; gerisi şeritsiz (parry varsayılan).
  Color? _profileColor(DefenseProfile d) =>
      d == DefenseProfile.guardBreak ? kBarRed : null;

  // --------------------------------------------------------------------------
  //  DEBUG OVERLAY  —  canlı combat metrikleri + durum (` / 0 ile aç-kapa)
  // --------------------------------------------------------------------------
  void _renderDebug(Canvas canvas) {
    final r = game.arenaRect;
    if (r.isEmpty) return;
    final boss = game.boss;
    final p = game.player;
    final m = game.metrics;

    final lines = <String>[
      'DEBUG (` veya 0)',
      'süre: ${m.fightDuration.toStringAsFixed(1)}s  faz: ${boss?.phase ?? '-'}',
      'boss HP: ${boss?.health ?? '-'}  denge: ${boss?.posture.round() ?? '-'}/${boss?.maxPosture ?? '-'}',
      'oyuncu HP: ${p.health}  tempo: ${p.hasTempo ? 'AÇIK' : '-'}',
      'parry: ${m.parrySuccesses}/${m.parryAttempts}  dodge: ${m.dodgeSuccesses}/${m.dodgeAttempts}',
      'vuruş L/H: ${m.lightHits}/${m.heavyHits}  ıska: ${m.attackWhiffs}',
      'denge kırma: ${m.bossPostureBreaks}  bossHasar: ${m.bossDamageTaken}  alınan: ${m.playerDamageTaken}',
    ];

    final panelW = 280.0;
    final panelH = 14.0 + lines.length * 16.0;
    final px = r.left + 8, py = r.top + 8;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(px, py, panelW, panelH),
        const Radius.circular(3),
      ),
      Paint()..color = kBlack.withAlpha(180),
    );
    final tp = TextPaint(
      style: const TextStyle(color: kWhite, fontSize: 11, height: 1.0),
    );
    double ly = py + 8;
    for (final l in lines) {
      tp.render(canvas, l, Vector2(px + 8, ly));
      ly += 16;
    }
  }

  // --------------------------------------------------------------------------
  //  HP BARI  —  orijinal _hpBar düzeni, 'elements' renklerinde
  // --------------------------------------------------------------------------
  void _hpBar(
    Canvas canvas,
    double x,
    double y,
    double w,
    String label,
    Color color,
    int hp,
    double disp, {
    double maxVal = 100,
  }) {
    _section.render(canvas, label, Vector2(x, y));
    _hpNum.render(canvas, '$hp', Vector2(x + w - 28, y - 1));

    final track = Rect.fromLTWH(x, y + 16, w, 12);
    final trackRR = RRect.fromRectAndRadius(track, const Radius.circular(2));
    canvas.drawRRect(trackRR, Paint()..color = kUiWoodDark);

    final double f = (disp / maxVal).clamp(0, 1).toDouble();
    if (f > 0) {
      final fill = Rect.fromLTWH(x, y + 16, w * f, 12);
      final fillRR = RRect.fromRectAndRadius(fill, const Radius.circular(2));
      canvas.drawRRect(fillRR, Paint()..color = color);
      // üst kenar parlaklığı (PixelBar görünümü)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y + 16, w * f, 3),
          const Radius.circular(2),
        ),
        Paint()..color = Color.lerp(color, kWhite, 0.35)!,
      );
    }
    // dış piksel kenar
    canvas.drawRRect(
      trackRR,
      Paint()
        ..color = kUiWood
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  // --------------------------------------------------------------------------
  //  YARDIMCILAR
  // --------------------------------------------------------------------------
  void _divider(Canvas canvas, double x, double y, double w) {
    canvas.drawLine(
      Offset(x, y),
      Offset(x + w, y),
      Paint()
        ..color = kUiParchEdge
        ..strokeWidth = 2,
    );
  }

  String _classTr(CharClass c) {
    switch (c) {
      case CharClass.knight:
        return 'ŞÖVALYE';
      case CharClass.wizard:
        return 'BÜYÜCÜ';
    }
  }

  // basit kelime kaydırma (en fazla maxLines satır)
  void _wrapText(
    Canvas canvas,
    TextPaint tp,
    String text,
    double x,
    double y,
    double maxW,
    int maxLines,
  ) {
    final words = text.split(' ');
    final lines = <String>[];
    String line = '';
    for (final word in words) {
      final test = line.isEmpty ? word : '$line $word';
      final m = tp.getLineMetrics(test);
      if (m.width > maxW && line.isNotEmpty) {
        lines.add(line);
        line = word;
        if (lines.length >= maxLines - 1) break;
      } else {
        line = test;
      }
    }
    if (line.isNotEmpty && lines.length < maxLines) lines.add(line);

    double ly = y;
    for (final l in lines) {
      tp.render(canvas, l, Vector2(x, ly));
      ly += 15;
    }
  }
}
