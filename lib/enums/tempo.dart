enum Tempo {
  grave(40),
  largo(44),
  largamente(46),
  adagio(48),
  lento(50),
  lantamente(52),
  larghetto(54),
  andante(58),
  moderato(80),
  alegretto(92),
  animato(100),
  di_marcia(112),
  allegto(120),
  vivo(160),
  vivace(176),
  presto(184),
  prestissimo(192);

  final int value;
  const Tempo(this.value);
}