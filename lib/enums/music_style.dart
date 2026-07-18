enum MusicStyle {
  any('any'),
  blues('blues'),
  barocco('barocco'),
  classical('classical'),
  country('country'),
  disco('disco'),
  folk('folk'),
  gregorian('gregorian'),
  hiphop('hip-Hop'),
  jazz('jazz'),
  latino('latino'),
  metal('metal'),
  pop('pop'),
  reggae('raggae'),
  rock('rock'),
  techno('techno');

  final String label;
  const MusicStyle(this.label);
}