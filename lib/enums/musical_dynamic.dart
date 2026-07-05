enum MusicalDynamic {
  ppp('ppp'),
  pp('pp'),
  p('p'),
  mp('mp'),
  mf('mf'),
  f('f'),
  ff('ff'),
  fff('fff'),
  sfz('sfz');

  final String value;

  const MusicalDynamic(this.value);
}