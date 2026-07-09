import 'measure.dart';
import 'time_signature.dart';
import 'tempo_event.dart'; // Ensure this model import exists!

class Timeline {
  final List<Measure> measures;

  // ================= TEMPO EVENTS STORAGE =================
  final List<TempoEvent> tempoEvents;

  Timeline({
    required this.measures,
    List<TempoEvent>? tempoEvents,
  }) : tempoEvents = tempoEvents ?? [] {
    // Inject a fallback default timeline engine speed at tick 0 if empty
    if (this.tempoEvents.isEmpty) {
      this.tempoEvents.add(TempoEvent(tick: 0, bpm: 120));
    }
    _sortTempoEvents();
  }

  int get totalTicks {
    int sum = 0;
    for (final m in measures) {
      sum += m.lengthTicks;
    }
    return sum;
  }

  // ================= ADD MEASURE =================

  void addMeasure(TimeSignature sig) {
    measures.add(
      Measure(
        id: measures.length,
        startTick: totalTicks,
        timeSignature: sig,
      ),
    );
  }

  // ================= INSERT MEASURE =================

  void insertMeasure(int index, TimeSignature sig) {
    measures.insert(
      index,
      Measure(
        id: index,
        startTick: 0,
        timeSignature: sig,
      ),
    );
    _rebuild();
  }

  // ================= DELETE MEASURE =================

  void deleteMeasure(int index) {
    if (index < 0 || index >= measures.length) return;
    measures.removeAt(index);
    _rebuild();
  }

  // ================= INTERNAL REBUILD =================

  void _rebuild() {
    int tick = 0;
    for (int i = 0; i < measures.length; i++) {
      measures[i]
        ..id = i
        ..startTick = tick;
      tick += measures[i].lengthTicks;
    }
  }

  // ============== CHANGE TIME SIGNATURE ===========

  void changeSignature(int index, TimeSignature sig) {
    if (index < 0 || index >= measures.length) return;
    measures[index].timeSignature = sig;
    _rebuild();
  }

  // ================= TEMPO UTILITIES =================

  void _sortTempoEvents() {
    tempoEvents.sort((a, b) => a.tick.compareTo(b.tick));
  }

  void addTempoEvent(TempoEvent event) {
    tempoEvents.removeWhere((e) => e.tick == event.tick);
    tempoEvents.add(event);
    _sortTempoEvents();
  }

  void removeTempoEvent(TempoEvent event) {
    if (event.tick == 0) return; // Keep anchor tempo protected
    tempoEvents.removeWhere((e) => e.tick == event.tick);
  }
}