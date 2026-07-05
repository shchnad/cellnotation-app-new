enum PlayingTechnique {
  none(''),
  pizzicato('pz'),
  arco('ar'),
  spiccato('sp'),
  ricochet('rc'),
  vibrato('vb'),
  flageolet('fl'),
  slapping('sl'),
  portamento('pt');

  final String abbreviation;

  const PlayingTechnique(this.abbreviation);
}