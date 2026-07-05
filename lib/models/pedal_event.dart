class PedalEvent {
  final int tick;
  final bool down;

  const PedalEvent({
    required this.tick,
    required this.down,
  });
}