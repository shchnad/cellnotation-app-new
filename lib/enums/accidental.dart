enum Accidental {
  sharp('sharp', '+'),
  flat('flat','-'),
  natural('natural', 'x'),
  doubleSharp('double sharp', '++'),
  doubleFlat('double flat', '--');

  final String label;
  final String sign;

  const Accidental(this.label, this.sign);

}