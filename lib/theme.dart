// ============================================================================
//  THEME  —  orijinal minimal palet + 'elements' yeşil/parşömen piksel kiti
// ----------------------------------------------------------------------------
//  - kBlack..kHair: orijinal FIGHT sahnesi paleti (değiştirilmedi).
//  - kUi*/kBar*:    menü/UI kromu için chunky piksel 'elements' paleti.
//  - PixelButton/PixelFrame/PixelBar/PixelPortrait: elements görünümünü
//    koddan üreten Flutter widget'ları (yumuşak gölge yok, 0/2px köşe).
// ============================================================================

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'input_settings.dart';

// ----------------------------------------------------------------------------
//  ORİJİNAL PALET (değiştirilmedi)
// ----------------------------------------------------------------------------
const Color kBlack = Color(0xFF141414);
const Color kWhite = Color(0xFFFFFFFF);
const Color kGray300 = Color(0xFFD4D4D4);
const Color kGray500 = Color(0xFF9C9C9C);
const Color kGray700 = Color(0xFF5C5C5C);
const Color kGray800 = Color(0xFF3A3A3A);
const Color kTrack = Color(0xFFEAEAEA);
const Color kHair = Color(0xFFCFCFCF);

// ----------------------------------------------------------------------------
//  EASING (popup/kombo yazısı pop-in'i için)
// ----------------------------------------------------------------------------
double easeOutBack(double t) {
  const c1 = 1.70158, c3 = c1 + 1;
  return 1 + c3 * pow(t - 1, 3).toDouble() + c1 * pow(t - 1, 2).toDouble();
}

// ----------------------------------------------------------------------------
//  ELEMENTS PALETİ (yeşil/ahşap piksel kiti)
// ----------------------------------------------------------------------------
const Color kUiGreen = Color(0xFF5CA05A); // green mid (buton dolgusu)
const Color kUiGreenLight = Color(0xFF8FD27A); // green light (üst kenar)
const Color kUiGreenDark = Color(0xFF2E5E33); // green dark (kenarlık)
const Color kUiParchment = Color(0xFFE9DCB4); // parchment (panel zemini)
const Color kUiParchEdge = Color(0xFFC9B68A); // parchment edge
const Color kUiWood = Color(0xFF5A3D28); // wood dark (panel kenarı)
const Color kUiWoodDark = Color(0xFF3C2718); // wood darker
const Color kBarRed = Color(0xFFC0392B);
const Color kBarGreen = Color(0xFF4CAF50);
const Color kBarBlue = Color(0xFF3E78C4);

const Color kTextDark = Color(0xFF2A2A2A); // parşömen üstü metin
const Color kTextLight = Color(0xFFF4F4E8); // yeşil buton üstü metin

// ============================================================================
//  PIXEL BUTTON  —  yeşil piksel buton (primary) / parşömen kontur (else)
// ============================================================================
class PixelButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool selected;
  final double? width;
  final String controllerFocusScope;

  const PixelButton({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = true,
    this.selected = false,
    this.width,
    this.controllerFocusScope = 'global',
  });

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  late final FocusNode _focusNode = FocusNode(debugLabel: widget.label);
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    ControllerFocusRegistry.instance.register(
      _focusNode,
      widget.onTap,
      scope: widget.controllerFocusScope,
    );
  }

  @override
  void didUpdateWidget(covariant PixelButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    ControllerFocusRegistry.instance.register(
      _focusNode,
      widget.onTap,
      scope: widget.controllerFocusScope,
    );
  }

  @override
  void dispose() {
    ControllerFocusRegistry.instance.unregister(_focusNode);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color fill = widget.primary ? kUiGreen : kUiParchment;
    final Color border = widget.primary ? kUiGreenDark : kUiWood;
    final Color top = widget.primary ? kUiGreenLight : kUiParchEdge;
    final Color txt = widget.primary ? kTextLight : kTextDark;

    return Focus(
      focusNode: _focusNode,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: widget.width,
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            // NOT: borderRadius + non-uniform (bevel) Border birlikte kullanılamaz;
            // pixel görünüm için köşeler keskin bırakıldı.
            border: Border(
              top: BorderSide(color: top, width: 2),
              left: BorderSide(color: border, width: 3),
              right: BorderSide(color: border, width: 3),
              bottom: BorderSide(color: border, width: 4),
            ),
            boxShadow: widget.selected || _focused
                ? [
                    BoxShadow(
                      color: _focused ? kBarBlue : kUiGreenLight,
                      blurRadius: 0,
                      spreadRadius: 3,
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: txt,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
//  PIXEL FRAME  —  parşömen panel + ahşap kenarlık (overlay panelleri & sidebar)
// ============================================================================
class PixelFrame extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? width;

  const PixelFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: kUiWoodDark,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: kUiWoodDark, width: 2),
      ),
      padding: const EdgeInsets.all(4),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: kUiParchment,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: kUiWood, width: 3),
        ),
        child: child,
      ),
    );
  }
}

// ============================================================================
//  PIXEL BAR  —  etiketli HP/stat barı (koyu track + renkli dolgu + piksel kenar)
// ============================================================================
class PixelBar extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  final double height;
  final String? label;
  final String? trailing;

  const PixelBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 12,
    this.label,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null || trailing != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label ?? '',
                  style: const TextStyle(
                    color: kTextDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                if (trailing != null)
                  Text(
                    trailing!,
                    style: const TextStyle(
                      color: kTextDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: kUiWoodDark,
            border: Border.all(color: kUiWood, width: 2),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: v,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  border: Border(
                    top: BorderSide(
                      color: Color.lerp(color, kWhite, 0.35)!,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
//  PIXEL PORTRAIT  —  yatay sprite-strip PNG'sinin TEK karesini CustomPaint ile
//  çizer (asset = tam 'assets/images/...png' yolu). Kare kaynak hücreler.
// ============================================================================
class PixelPortrait extends StatefulWidget {
  final String asset; // ör. 'assets/images/chars/knight_1/idle.png'
  final int frameCount;
  final int frame;
  final double size;

  const PixelPortrait({
    super.key,
    required this.asset,
    required this.frameCount,
    this.frame = 0,
    this.size = 72,
  });

  @override
  State<PixelPortrait> createState() => _PixelPortraitState();
}

class _PixelPortraitState extends State<PixelPortrait> {
  ui.Image? _image;
  Rect?
  _content; // gösterilen karenin saydam-olmayan içerik sınırı (image uzayı)

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PixelPortrait oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset || oldWidget.frame != widget.frame) {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final data = await rootBundle.load(widget.asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final content = await _contentBounds(frame.image);
      if (mounted) {
        setState(() {
          _image = frame.image;
          _content = content;
        });
      }
    } catch (_) {
      // asset yoksa boş bırak
    }
  }

  /// Gösterilen karenin içindeki karakterin (saydam-olmayan piksellerin) sıkı
  /// sınır kutusunu image koordinatlarında hesaplar. Böylece sprite, hücredeki
  /// boş alana aldırmadan kutunun MERKEZİNE yerleştirilebilir.
  Future<Rect> _contentBounds(ui.Image img) async {
    final int frameCount = widget.frameCount;
    final int frame = widget.frame.clamp(0, frameCount - 1);
    final int cellW = (img.width / frameCount).floor();
    final int cellH = img.height;
    final int x0 = frame * cellW;
    final Rect full = Rect.fromLTWH(
      x0.toDouble(),
      0,
      cellW.toDouble(),
      cellH.toDouble(),
    );

    final bytes = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytes == null) return full;
    final px = bytes.buffer.asUint8List();

    int minX = cellW, minY = cellH, maxX = -1, maxY = -1;
    for (int y = 0; y < cellH; y++) {
      final rowBase = y * img.width;
      for (int x = 0; x < cellW; x++) {
        final alpha = px[(rowBase + x0 + x) * 4 + 3];
        if (alpha > 16) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX < 0) return full; // tamamen saydam
    return Rect.fromLTWH(
      (x0 + minX).toDouble(),
      minY.toDouble(),
      (maxX - minX + 1).toDouble(),
      (maxY - minY + 1).toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: kUiParchEdge,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: kUiWood, width: 3),
      ),
      child: (_image == null || _content == null)
          ? const SizedBox.shrink()
          : CustomPaint(
              painter: _StripPainter(image: _image!, src: _content!),
            ),
    );
  }
}

class _StripPainter extends CustomPainter {
  final ui.Image image;
  final Rect src; // çizilecek içerik kutusu (image uzayı)

  _StripPainter({required this.image, required this.src});

  @override
  void paint(Canvas canvas, Size size) {
    // İçeriği en-boy oranını koruyarak (contain) ve hafif kenar boşluğuyla
    // kutunun MERKEZİNE yerleştir.
    final double pad = size.shortestSide * 0.08;
    final double availW = size.width - pad * 2;
    final double availH = size.height - pad * 2;
    final double scale = min(availW / src.width, availH / src.height);
    final double w = src.width * scale;
    final double h = src.height * scale;
    final dst = Rect.fromLTWH(
      (size.width - w) / 2,
      (size.height - h) / 2,
      w,
      h,
    );
    final paint = Paint()..filterQuality = FilterQuality.none;
    canvas.drawImageRect(image, src, dst, paint);
  }

  @override
  bool shouldRepaint(covariant _StripPainter old) =>
      old.image != image || old.src != src;
}
