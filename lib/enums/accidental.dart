enum Accidental {
  none(''),
  sharp('+'),
  flat('-'),
  doubleSharp('++'),
  doubleFlat('--');

  final String value;
  const Accidental(this.value);
}