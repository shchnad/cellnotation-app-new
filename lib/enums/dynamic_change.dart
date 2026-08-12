enum DynamicChange {
  crescendoStart('crescendo begins'),
  crescendoFinish('crescendo ends'),
  diminuendoStart('diminuendo begins'),
  diminuendoFinish('diminuendo ends'),
  pedalDown('pedal on'),
  // The Dart member name stays `pedalUp` for persistence safety —
  // renaming it would orphan the event on any composition already
  // saved with the old name. Its LABEL is "none" though: this is the
  // "pedal is off starting here" marker, and displaying it as "None"
  // (matching how every other unset field in the app reads, e.g.
  // "Finger: none") is clearer than an active-sounding "Pedal Up" —
  // see editMeasureBeatDialog's pedal toggle, which shows this same
  // wording.
  pedalUp('pedal off');

  final String label;

  const DynamicChange(this.label);
}