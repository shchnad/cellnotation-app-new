enum Accidental {
  sharp('sharp', '+'),
  flat('flat','-'),
  doubleSharp('double sharp', '++'),
  doubleFlat('double flat', '--'),
  // Explicitly cancels any alteration in effect for this note — either
  // the scale's own inherent +/- for this degree, or an earlier
  // accidental still persisting through the measure. Used by
  // CompositionController.compensateAccidentals() to mark a note as
  // deliberately natural once its own accidental and the scale's
  // inherent sign have been reconciled.
  natural('natural', 'x');

  final String label;
  final String sign;

  const Accidental(this.label, this.sign);

}