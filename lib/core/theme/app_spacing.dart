/// Spacing and radius tokens extracted from the Stitch design export.
/// Values converted from rem (Stitch/Tailwind, 1rem = 16px) to logical
/// pixels for Flutter.
class AppSpacing {
  AppSpacing._();

  // ── Spacing scale (from DESIGN.md `spacing`) ──────────────────────
  /// 1.5rem — standard screen-edge horizontal padding
  static const double marginMain = 24.0;

  /// 1rem — gap between items in a row/grid (e.g. shop cards)
  static const double gutter = 16.0;

  /// 0.5rem — tight vertical rhythm (e.g. label to value)
  static const double stackSm = 8.0;

  /// 1rem — standard vertical rhythm between elements
  static const double stackMd = 16.0;

  /// 2rem — section-level separation
  static const double stackLg = 32.0;

  // ── Radius scale (matched to actual rendered screens, not the
  // DESIGN.md front-matter labels, which don't quite match the
  // per-screen Tailwind overrides) ───────────────────────────────────
  /// 0.25rem — small elements: badges, small chips
  static const double radiusSm = 4.0;

  /// 0.5rem — cards, input fields, bottom sheets
  static const double radiusMd = 8.0;

  /// 0.75rem — larger containers, modals
  static const double radiusLg = 12.0;

  /// Pill shape — primary/secondary buttons, filter chips, nav items
  static const double radiusFull = 9999.0;
}
