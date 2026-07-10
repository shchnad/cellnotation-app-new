enum MusicStyle {
  any('Any'),
  blues('Blues'),
  barocco('Barocco'),
  classical('Classical'),
  country('Country'),
  disco('Disco'),
  folk('Folk'),
  gregorian('Gregorian'),
  hiphop('Hip-Hop'),
  jazz('Jazz'),
  latino('Latino'),
  metal('Metal'),
  pop('Pop'),
  reggae('Raggae'),
  rock('Rock'),
  techno('Techno');

  final String label;
  const MusicStyle(this.label);
}