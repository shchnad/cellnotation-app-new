import '../enums/music_style.dart';
import '../enums/instrument.dart';
import '../enums/note_duration.dart';

class DefaultValues {

  // INPUT INITIAL VALUES
  static const title = '';
  static const composer = '';
  static const style = MusicStyle.classical;
  static const instrument = Instrument.piano;
  static const scale = 'major C';
  static const NoteDuration defaultDuration = NoteDuration.eighth; // 1/8
  static const int defaultBeatsPerMeasure = 4;
  static const List possibleNumberOfBeatsInMeasure = [1,2,3,4,5,6,7,8,9,12];
  static const int maxOfMeasuresToAddAtOnce = 10;
  static const String defaultNumberOfMeasures = '1';

  // DESIGN VALUES
  static const double widthOfElevatedButton = 220.0;

  static const double widthBetweenWidgets = 20.0;
  static const double heightBetweenWidgets = 8.0;

  static const double dialogPaddingRightLeft = 25.0;
  static const double dialogPaddingBottomTop = 8.0;

  // Shared font size for every grid annotation label — finger number,
  // time signature, pedal sign, dynamic, tempo, scale name, and
  // measure number. Toggleable at runtime between this default and
  // 22 (see CompositionController.gridFontSize /
  // toggleGridFontSize).
  static const double gridFontSize = 16.0;
  static const double gridFontSizeLarge = 22.0;

}