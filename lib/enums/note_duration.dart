enum NoteDuration {
  whole(64, '1'),
  half(32, '1/2'),
  quarter(16, '1/4'),
  eighth(8, '1/8'),
  sixteenth(4, '1/16'),
  thirtySecond(2, '1/32'),
  sixtyFourth(1, '1/64');

  final int ticks; //number of ticks in a beat of chosen note duration
  final String label;

  const NoteDuration(this.ticks, this.label);
}