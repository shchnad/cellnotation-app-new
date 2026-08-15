import 'package:flutter/material.dart';

/// Central place for every color that needs to flip between light and
/// dark mode (see CompositionController.isDarkMode / toggleDarkMode).
/// Every file that previously hardcoded Colors.white/Colors.black for
/// its background/surface/primary text now reads these instead, keyed
/// off the SAME isDarkMode flag, so toggling it inverts the whole app
/// consistently rather than one screen at a time.
///
/// Deliberately NOT touched here: semantic colors that carry MEANING
/// rather than just light/dark contrast — red for delete/destructive
/// actions, green for dynamics/pedal/hairpins/highlighted-accidental
/// notes, blue for links/selected-state/right-hand notes. Those stay
/// the same in both modes, the same way most apps keep a "delete" red
/// red regardless of theme.
class AppColors {
  const AppColors._();

  /// Scaffold-level background — the main canvas behind everything.
  static Color background(bool isDarkMode) =>
      isDarkMode ? Colors.black : Colors.white;

  /// Dialog/card surfaces (AlertDialog's own backgroundColor/
  /// surfaceTintColor) — slightly lighter than pure black in dark
  /// mode so a dialog still reads as a distinct surface floating
  /// above the background, the way white-on-white-ish grey does in
  /// light mode.
  static Color surface(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

  /// The left toolbar's own background — was a flat
  /// Colors.grey.shade300 in light mode; a comparably-toned dark grey
  /// in dark mode, rather than pure black, so the toolbar still reads
  /// as a distinct strip next to the pure-black canvas.
  static Color toolbarBackground(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade300;

  /// Primary text/icon color — was Colors.black everywhere in light
  /// mode.
  static Color primaryText(bool isDarkMode) =>
      isDarkMode ? Colors.white : Colors.black;

  /// Secondary/muted text — was Colors.black54.
  static Color secondaryText(bool isDarkMode) =>
      isDarkMode ? Colors.white70 : Colors.black54;

  /// Toolbar icons in their "off" state — was Colors.black. Toggled-
  /// "on" icons keep their own semantic color (blue/green/red) in
  /// both modes, unchanged.
  static Color icon(bool isDarkMode) =>
      isDarkMode ? Colors.white : Colors.black;

  /// Divider lines — was the Divider/VerticalDivider default (a
  /// light grey) in light mode; a low-opacity white in dark mode so
  /// it's still visible against a black surface.
  static Color divider(bool isDarkMode) =>
      isDarkMode ? Colors.white24 : Colors.black26;

  /// Grid background fill — the grid previously had no explicit
  /// background of its own, relying on the white Scaffold behind it;
  /// now painted explicitly so it can be black in dark mode.
  static Color gridBackground(bool isDarkMode) =>
      isDarkMode ? Colors.black : Colors.white;

  /// Thin thin/beat grid lines — these are the plain row-separator
  /// lines, so visibility matters a lot here in particular. Were
  /// Colors.grey at ~25% opacity in light mode; bumped up to 35% white
  /// in dark mode (rather than a fainter 15%, which read as barely
  /// visible against a pure black background).
  static Color gridLineThin(bool isDarkMode) => isDarkMode
      ? Colors.white.withOpacity(0.35)
      : Colors.grey.withOpacity(0.25);

  /// Octave/beat-boundary lines (were Colors.grey at ~55% opacity).
  static Color gridLineMedium(bool isDarkMode) => isDarkMode
      ? Colors.white.withOpacity(0.45)
      : Colors.grey.withOpacity(0.55);

  /// Measure boundary / middle-octave lines (were Colors.black at
  /// ~75% opacity).
  static Color gridLineStrong(bool isDarkMode) => isDarkMode
      ? Colors.white.withOpacity(0.75)
      : Colors.black.withOpacity(0.75);

  /// Text color for the grid's own annotation labels — time
  /// signature, tempo, scale name, measure number (see
  /// grid_widget.dart's _tempoLabelStyle/_scaleLabelStyle/
  /// _measureNumberLabelStyle/_measureLabelStyle). These were always
  /// plain Colors.blue; kept in light mode, but flipped to white in
  /// dark mode for legibility against the black grid background.
  static Color gridLabelText(bool isDarkMode) =>
      isDarkMode ? Colors.white : Colors.black;

  /// A right-hand note's fill color (was plain Colors.black).
  static Color noteHandRight(bool isDarkMode) =>
      isDarkMode ? Colors.white : Colors.black;

  /// A left-hand note's fill color — kept blue in light mode; a
  /// LIGHT blue in dark mode instead of the same dark blue (unlike
  /// the earlier design), so its own inner text needs to flip to
  /// black there too — see [noteText].
  static Color noteHandLeft(bool isDarkMode) =>
      isDarkMode ? Colors.orangeAccent.shade100 : Colors.blue;

  /// Text drawn INSIDE a note block (pitch/accidental) — was always
  /// plain Colors.white, since both fills (black right-hand, blue
  /// left-hand) were dark in light mode. In dark mode BOTH fills are
  /// now light (white right-hand, light blue left-hand — see
  /// [noteHandRight]/[noteHandLeft]), so both hands need black text
  /// there instead; no longer hand-specific, since dark mode always
  /// means a light fill and light mode always means a dark one.
  static Color noteText(bool isDarkMode) =>
      isDarkMode ? Colors.black : Colors.white;

  /// The articulation mark drawn above a note (staccato/tenuto/
  /// marcato/accent — see NoteBlockWidget's _ArticulationMarkPainter)
  /// and the playing technique abbreviation drawn below one (see
  /// _techniqueTextStyle) — both were plain Colors.red; switched to
  /// yellow in dark mode, since red reads poorly against a black
  /// background.
  static Color redMark(bool isDarkMode) =>
      isDarkMode ? Colors.yellow : Colors.red;
}