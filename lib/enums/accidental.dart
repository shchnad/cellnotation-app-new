enum Accidental {
  sharp('Sharp', '+'),
  flat('Flat','-'),
  doubleSharp('Double Sharp', '++'),
  doubleFlat('Double Flat', '--');

  final String label;
  final String sign;

  const Accidental(this.label, this.sign);

}

