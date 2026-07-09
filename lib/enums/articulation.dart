enum Articulation {
  staccato('Staccato'),
  tenuto('Tenuto'),
  legato('Legato'),
  marcato('Marcato'),
  accent('Accent'),
  sforzando('Sforzando'),
  fermata('Fermata');

  final String label;
  const Articulation(this.label);
}
