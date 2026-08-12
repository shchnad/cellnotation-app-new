enum PlayingTechnique {
  pizzicato('pizzicato', 'pz'),
  arco('arco', 'ar'),
  spiccato('spiccato', 'sp'),
  ricochet('ricochet', 'rc'),
  vibrato('vibrato', 'vb'),
  flageolet('flageolet', 'fl'),
  slapping('slapping', 'sl'),
  portamento('portamento', 'pt'),
  pedalDown('pedal down','ped'),
  pedalUp('pedal up','*');

  final String label;
  final String abbreviation;

  const PlayingTechnique(
      this.label,
      this.abbreviation,
      );
}