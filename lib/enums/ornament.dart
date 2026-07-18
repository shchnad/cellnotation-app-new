enum Ornament {
  mordent('mordent'),
  invertedMordent('inverted mordent'),
  turn('turn'),
  invertedTurn('inverted turn'),
  trill('trill'),
  tremolo('tremolo'),
  tuplet3('tuplet 3'),
  tupletFive('tuplet 5'),
  graceNote('grace note');

  final String label;
  const Ornament(this.label);
}