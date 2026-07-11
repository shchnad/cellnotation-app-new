import 'measure.dart';
import 'time_signature.dart';
import 'tempo_event.dart';


class Timeline {

  final List<Measure> measures;

  final List<TempoEvent> tempoEvents;


  Timeline({
    required this.measures,
    List<TempoEvent>? tempoEvents,
  }) : tempoEvents = tempoEvents ?? [] {


    if(this.tempoEvents.isEmpty){
      this.tempoEvents.add(
        TempoEvent( tick: 0, bpm: 120,),
      );
    }
    rebuild();
    _sortTempoEvents();
  }


  // =====================================================
  // TOTAL LENGTH
  // =====================================================

  int get totalTicks {
    if(measures.isEmpty){
      return 0;
    }
    return measures.last.endTick;
  }


  // =====================================================
  // MEASURE MANAGEMENT
  // =====================================================


  void addMeasure(
      TimeSignature signature,
      String scaleName,
      ) {
    measures.add(
      Measure(
        id: measures.length,
        startTick: totalTicks,
        timeSignature: signature,
        scaleName: scaleName,
      ),
    );
    rebuild();
  }


  void insertMeasure(
      int index,
      TimeSignature signature,
      String scaleName,
      ){
    measures.insert(
      index,
      Measure(
        id: index,
        startTick: 0,
        timeSignature: signature,
        scaleName: scaleName,
      ),
    );
    rebuild();
  }


  void deleteMeasure(int index){
    if(index < 0 ||
        index >= measures.length){
      return;
    }
    measures.removeAt(index);
    rebuild();
  }


  // =====================================================
  // TICK RECALCULATION
  // =====================================================


  void rebuild(){
    int tick = 0;
    for(int i = 0;
    i < measures.length;
    i++){
      final measure = measures[i];
      measure.id = i;
      measure.startTick = tick;
      tick += measure.durationTicks;
    }
  }

  // =====================================================
  // BEAT EDITING
  // =====================================================

  void addBeat(
      int measureIndex,
      ){
    if(!_validIndex(measureIndex)){
      return;
    }
    measures[measureIndex].addBeat();
    rebuild();
  }


  void removeBeat(
      int measureIndex,
      ){
    if(!_validIndex(measureIndex)){
      return;
    }
    measures[measureIndex].removeBeat();
    rebuild();
  }


  void changeTimeSignature(
      int measureIndex,
      TimeSignature signature,
      ){
    if(!_validIndex(measureIndex)){
      return;
    }
    measures[measureIndex].timeSignature = signature;
    rebuild();
  }


  bool _validIndex(int index){
    return index >= 0 && index < measures.length;
  }


  // =====================================================
  // TEMPO
  // =====================================================


  void addTempoEvent(
      TempoEvent event,
      ){
    tempoEvents.removeWhere(
            (e)=>e.tick == event.tick
    );
    tempoEvents.add(event);
    _sortTempoEvents();
  }


  void removeTempoEvent(
      TempoEvent event,
      ){
    if(event.tick == 0){
      return;
    }
    tempoEvents.removeWhere(
            (e)=>e.tick == event.tick
    );
  }


  void _sortTempoEvents(){
    tempoEvents.sort(
            (a,b)=>
            a.tick.compareTo(b.tick)
    );
  }
}