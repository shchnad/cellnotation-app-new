import '../enums/tempo.dart';
import 'beat_event_model.dart';
import 'dynamic_change_event.dart';
import 'dynamic_event.dart';
import 'measure.dart';
import 'time_signature.dart';
import 'tempo_event.dart';



class Timeline {
  final List<Measure> measures;
  final List<TempoEvent> tempoEvents;
  final List<DynamicEvent> dynamicEvents;
  final List<BeatEvent> beatEvents;
  final List<DynamicChangeEvent> dynamicChangeEvents;

  Timeline({
    required this.measures,
    List<TempoEvent>? tempoEvents,
    List<DynamicEvent>? dynamicEvents,
    List<DynamicChangeEvent>? dynamicChangeEvents,
    List<BeatEvent>? beatEvents,
  }) :
        tempoEvents = tempoEvents ?? [],
        dynamicEvents = dynamicEvents ?? [],
        dynamicChangeEvents = dynamicChangeEvents ?? [],
        beatEvents = beatEvents ?? [] {
    if(this.tempoEvents.isEmpty){
      this.tempoEvents.add(
        TempoEvent(
          tick: 0,
          tempo: Tempo.moderato,
        ),
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
        originalScaleName: scaleName,
      ),
    );
    rebuild();
  }


  void insertMeasure(
      int index,
      TimeSignature signature,
      String scaleName,
      ){
    final tick = index == 0
        ? 0
        : measures[index-1].endTick;
    measures.insert(
      index,
      Measure(
        id:index,
        startTick:tick,
        timeSignature:signature,
        scaleName:scaleName,
        originalScaleName: scaleName,
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


  void addTempoEvent(TempoEvent event){
    tempoEvents.removeWhere(
            (e)=>e.tick == event.tick
    );
    tempoEvents.add(event);
    _sortTempoEvents();
  }

  void removeTempoEvent(TempoEvent event){
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

  void addBeatEvent(BeatEvent event){
    beatEvents.removeWhere(
            (e)=>e.tick == event.tick
    );
    beatEvents.add(event);
    beatEvents.sort(
            (a,b)=>a.tick.compareTo(b.tick)
    );
  }

  void removeBeatEvent(int tick){
    beatEvents.removeWhere(
            (e)=>e.tick == tick
    );
  }


// =====================================================
// DYNAMICS
// =====================================================

  void addDynamicEvent(DynamicEvent event) {
    dynamicEvents.removeWhere(
          (e) => e.tick == event.tick,
    );
    dynamicEvents.add(event);
    _sortDynamicEvents();
  }

  void removeDynamicEvent(int tick) {
    dynamicEvents.removeWhere(
          (e) => e.tick == tick,
    );
  }

  void _sortDynamicEvents() {
    dynamicEvents.sort(
          (a, b) => a.tick.compareTo(b.tick),
    );
  }

  //==============================
  //     DYNAMIC CHANGE EVENT
  //==============================

  void addDynamicChangeEvent(DynamicChangeEvent event) {
    dynamicChangeEvents.removeWhere(
          (e) => e.tick == event.tick,
    );
    dynamicChangeEvents.add(event);
    _sortDynamicChangeEvents();
  }


  void removeDynamicChangeEvent(int tick) {
    dynamicChangeEvents.removeWhere(
          (e) => e.tick == tick,
    );
  }


  void _sortDynamicChangeEvents() {
    dynamicChangeEvents.sort(
          (a, b) => a.tick.compareTo(b.tick),
    );
  }

  // ================= JSON =================


  Map<String, dynamic> toJson() {
    return {
      'measures': measures.map((m) => m.toJson()).toList(),
      'tempoEvents': tempoEvents.map((t) => t.toJson()).toList(),
      'dynamicEvents': dynamicEvents.map((d) => d.toJson()).toList(),
      'dynamicChangeEvents': dynamicChangeEvents.map((d) => d.toJson()).toList(),
      'beatEvents': beatEvents.map((e) => e.toJson()).toList(),
    };
  }

  factory Timeline.fromJson(Map<String, dynamic> json) {
    return Timeline(
      measures: (json['measures'] as List<dynamic>)
          .map((m) => Measure.fromJson(m as Map<String, dynamic>))
          .toList(),
      tempoEvents: (json['tempoEvents'] as List<dynamic>)
          .map((t) => TempoEvent.fromJson(t as Map<String, dynamic>))
          .toList(),
      beatEvents: (json['beatEvents'] as List<dynamic>)
          .map((e) => BeatEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      dynamicEvents: (json['dynamicEvents'] as List<dynamic>? ?? [])
          .map((d) => DynamicEvent.fromJson(d as Map<String, dynamic>))
          .toList(),
      dynamicChangeEvents: (json['dynamicChangeEvents'] as List<dynamic>? ?? [])
          .map((d) => DynamicChangeEvent.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }

}