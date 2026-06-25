class PlayerTimingRules {
  const PlayerTimingRules._();

  static bool parrySucceeds(double sinceParry, double effectiveWindow) =>
      sinceParry <= effectiveWindow;
}
