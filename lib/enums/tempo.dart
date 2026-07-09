enum Tempo {
  grave(40, 'Grave'),
  largo(44, 'Largo'),
  largamente(46, 'Largamento'),
  adagio(48, 'Adagio'),
  lento(50, 'Lento'),
  lantamente(52, 'Lantamente'),
  larghetto(54, 'Larghetto'),
  andante(58, 'Andante'),
  moderato(80, 'mederato'),
  alegretto(92, 'Alegretto'),
  animato(100, 'Animato'),
  di_marcia(112, 'Di Marcia'),
  allegto(120, 'Allegto'),
  vivo(160, 'Vivo'),
  vivace(176, 'Vivace'),
  presto(184, 'Presto'),
  prestissimo(192, 'Prestissimo');

  final int value;
  final String label;

  const Tempo(this.value, this.label);
}