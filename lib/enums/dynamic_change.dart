enum DynamicChange {
  crescendoStart('crescendo begins'),
  crescendoFinish('crescendo ends'),
  diminuendoStart('diminuendo begins'),
  diminuendoFinish('diminuendo ends');

  final String label;

  const DynamicChange(this.label);
}