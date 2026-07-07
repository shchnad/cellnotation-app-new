import 'measure.dart';
import 'time_signature.dart';

class Timeline {
  final List<Measure> measures;

  Timeline({required this.measures});

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
        signature: sig,
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
        signature: sig,
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
    measures[index].signature = sig;
    _rebuild();
  }

}