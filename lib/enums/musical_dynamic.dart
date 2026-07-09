enum MusicalDynamic {
  ppp('ppp', 'Piano Piano Piano'),
  pp('pp', 'Piano Piano'),
  p('p', 'Piano'),
  mp('mp', 'Mezzo Piano'),
  mf('mf', 'Mezzo Forte'),
  f('f', 'Forte'),
  ff('ff', 'Forte Forte'),
  fff('fff', 'Forte Forte Forte'),
  sfz('sfz', 'Sforzando');

  final String abbreviation;
  final String label;

  const MusicalDynamic(this.abbreviation, this.label);
}