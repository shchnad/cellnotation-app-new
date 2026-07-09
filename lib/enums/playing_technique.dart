enum PlayingTechnique {
  pizzicato('Pizzicato', 'pz'),
  arco('Arco', 'ar'),
  spiccato('Spiccato', 'sp'),
  ricochet('Ricochet', 'rc'),
  vibrato('Vibrato', 'vb'),
  flageolet('Flageolet', 'fl'),
  slapping('Slapping', 'sl'),
  portamento('Portamento', 'pt');

  final String label;
  final String abbreviation;

  const PlayingTechnique(
      this.label,
      this.abbreviation,
      );
}