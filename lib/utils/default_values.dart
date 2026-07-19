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

  // NOTE COPYING
  static const String titleOfMessageForCopying = 'Note copying';
  static const String messageForCopying =
      'Long-tap the note to copy it.\n\n'
      'The button gets blue showing Paste Mode is enable.\n\n'
      'You can clone this note than where ever you wish as many times as you wish.\n\n'
      'To disable Paste Mode toggle the button.';
  static const snackBarMessageForCopying = 'Paste Mode is disable';
// Message of copied note is in note_block_widget LongTap action.
}