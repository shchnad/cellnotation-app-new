enum Ornament {
  mordent('Mordent'),
  invertedMordent('Inverted Mordent'),
  turn('Turn'),
  invertedTurn('Inverted Turn'),
  trill('Trill'),
  tremolo('Tremolo'),
  tuplet3('Tuplet 3'),
  tupletFive('Tuplet 5'),
  graceNote('Grace Note');

  final String label;
  const Ornament(this.label);
}