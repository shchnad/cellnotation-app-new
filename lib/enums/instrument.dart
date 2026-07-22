enum Instrument {
  any('any'),
  piano('piano'),
  keyboard('keyboard'),
  organ('organ'),
  accordion('accordion'),
  bayan('bayan'),
  guitar6Strings('6 strings guitar'),
  guitar7Strings('7 strings guitar'),
  guitarElectro('electro guitar'),
  guitarBass('bass guitar'),
  cello('cello'),
  violin('violin'),
  ukelele('ukelele'),
  balalaika('balalaika'),
  banjo('banjo)'),
  harp('harp'),
  clarinet('clarinet'),
  cornet('cornet'),
  flute('flute'),
  horn('horn'),
  saxophone('saxophone'),
  trumpet('trumpet'),
  trombone('trombone'),
  xylophone('xylophone');

  final String label;
  const Instrument(this.label);
}