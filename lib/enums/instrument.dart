enum Instrument {
  any('any'),
  piano('Piano'),
  keyboard('Keyboard'),
  organ('Organ'),
  accordion('Accordion'),
  bayan('Bayan'),
  guitar6Strings('6 strings guitar'),
  guitar7Strings('7 strings guitar'),
  guitarElectro('Electro guitar'),
  guitarBass('Bass guitar'),
  cello('Cello'),
  violin('Violin'),
  ukelele('Ukelele'),
  balalaika('Balalaika'),
  banjo('Banjo)'),
  harp('Harp'),
  clarinet('Clarinet'),
  cornet('Cornet'),
  flute('Flute'),
  horn('Horn'),
  saxophone('Saxophone'),
  trumpet('Trumpet'),
  trombone('Trombone'),
  xylophone('Xylophone');

  final String label;
  const Instrument(this.label);
}