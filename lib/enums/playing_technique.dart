enum PlayingTechnique {
  pizzicato('pizzicato', 'pz'),
  arco('arco', 'ar'),
  spiccato('spiccato', 'sp'),
  ricochet('ricochet', 'rc'),
  vibrato('vibrato', 'vb'),
  flageolet('flageolet', 'fl'),
  slapping('slapping', 'sl'),
  portamento('portamento', 'pt');

  final String label;
  final String abbreviation;

  const PlayingTechnique(
      this.label,
      this.abbreviation,
      );
}