enum NoteDuration {
  whole(64, '1'),
  half(32, '1/2'),
  quarter(16, '1/4'),
  eighth(8, '1/8'),
  sixteenth(4, '1/16'),
  thirtySecond(2, '1/32'),
  sixtyFourth(1, '1/64');

  // quarter   = 16 ticks
  // eighth    = 8 ticks
  // sixteenth = 4 ticks
  // 1/32      = 2 ticks
  // 1/64      = 1 tick

  final int ticks;
  final String label;

  const NoteDuration(this.ticks, this.label);
}