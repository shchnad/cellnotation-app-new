enum Articulation {
  staccato('staccato'),
  tenuto('tenuto'),
  marcato('marcato'),
  accent('accent'),
  sforzando('sforzando');

  final String label;
  const Articulation(this.label);
}