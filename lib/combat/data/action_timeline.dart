// ============================================================================
//  ACTION TIMELINE  —  bir aksiyonun zaman çizelgesi (saf veri)
// ----------------------------------------------------------------------------
//  Bir aksiyonun (parry/dodge/light/heavy …) süre boyunca hangi pencerelerden
//  (windup/active/recovery/parry/iframe …) geçtiğini birinci-sınıf VERİ olarak
//  tutar. Hiçbir Flame/Flutter/Sfx bağı yoktur: yalnız zaman + pencere sorgusu.
//  Faz C: süre sabitleri Player içine dağılmak yerine buradan okunur.
//  Faz D: ActionEventMarker + AnimationBinding kareleri buradan beslenecek.
//  Mimari: architecture.md §6.1.
// ============================================================================

/// Bir aksiyon penceresinin türü. Mekanik anlamı taşır (sunum değil).
enum CombatWindowKind {
  windup,
  active,
  recovery,
  parry,
  iframe,
  cancel,
  superArmor,
  vulnerable,
}

/// [start, end] (saniye) aralığında geçerli olan tek bir pencere. Sınırlar dahil.
class ActionWindow {
  final CombatWindowKind kind;
  final double start;
  final double end;
  const ActionWindow(this.kind, this.start, this.end);

  /// Pencerenin süresi (saniye).
  double get duration => end - start;
}

/// Aksiyon zamanında belirli bir anda tetiklenecek isimli olay (Faz D: contact/
/// telegraph kareleri vb.). Şimdilik yer tutucu; davranışa karışmaz.
class ActionEventMarker {
  final double time;
  final String event;
  final Map<String, Object?> args;
  const ActionEventMarker(this.time, this.event, [this.args = const {}]);
}

/// Bir aksiyonun tam zaman çizelgesi: toplam süre + pencereler + olaylar.
class ActionTimeline {
  final String id;
  final double duration;
  final List<ActionWindow> windows;
  final List<ActionEventMarker> events;

  const ActionTimeline({
    required this.id,
    required this.duration,
    this.windows = const [],
    this.events = const [],
  });

  /// `t` anı `kind` türünden bir pencerenin içinde mi (sınırlar dahil)?
  bool isIn(CombatWindowKind kind, double t) =>
      windows.any((w) => w.kind == kind && t >= w.start && t <= w.end);

  /// `kind` türünden ilk pencere (yoksa null).
  ActionWindow? windowFor(CombatWindowKind kind) {
    for (final w in windows) {
      if (w.kind == kind) return w;
    }
    return null;
  }

  /// `kind` türünden pencerenin süresi (yoksa 0).
  double durationOf(CombatWindowKind kind) => windowFor(kind)?.duration ?? 0;
}
