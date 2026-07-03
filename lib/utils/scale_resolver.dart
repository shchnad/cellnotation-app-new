class ScaleResolver {
  static List<String> getScale(String name) {
    switch (name) {

    // MAJOR

      case 'major C':
        return ['1', '2', '3', '4', '5', '6', '7'];

      case 'major C sharp':
        return ['1+', '2+', '3+', '4+', '5+', '6+', '7+'];

      case 'major D flat':
        return ['1', '2-', '3-', '4', '5-', '6-', '7-'];

      case 'major D':
        return ['1+', '2', '3', '4+', '5', '6', '7'];

      case 'major E flat':
        return ['1', '2', '3-', '4', '5', '6-', '7-'];

      case 'major E':
        return ['1+', '2+', '3', '4+', '5+', '6', '7'];

      case 'major F':
        return ['1', '2', '3', '4', '5', '6', '7-'];

      case 'major F sharp':
        return ['1+', '2+', '3+', '4+', '5+', '6+', '7'];

      case 'major G flat':
        return ['1-', '2-', '3-', '4', '5-', '6-', '7-'];

      case 'major G':
        return ['1', '2', '3', '4+', '5', '6', '7'];

      case 'major A flat':
        return ['1', '2-', '3-', '4', '5', '6-', '7-'];

      case 'major A':
        return ['1+', '2', '3', '4+', '5+', '6', '7'];

      case 'major B flat':
        return ['1', '2', '3-', '4', '5', '6', '7-'];

    //  MINOR

      case 'minor C':
        return ['1', '2', '3-', '4', '5', '6-', '7-'];

      case 'minor C sharp':
        return ['1+', '2+', '3', '4+', '5+', '6', '7'];

      case 'minor D':
        return ['1', '2', '3', '4', '5', '6', '7-'];

      case 'minor D sharp':
        return ['1+', '2+', '3+', '4+', '5+', '6+', '7'];

      case 'minor E flat':
        return ['1-', '2-', '3-', '4', '5-', '6-', '7-'];

      case 'minor E':
        return ['1', '2', '3', '4+', '5', '6', '7'];

      case 'minor F':
        return ['1', '2-', '3-', '4', '5', '6-', '7-'];

      case 'minor F sharp':
        return ['1+', '2', '3', '4+', '5+', '6', '7'];

      case 'minor G':
        return ['1', '2', '3-', '4', '5', '6', '7-'];

      case 'minor G sharp':
        return ['1+', '2+', '3', '4+', '5+', '6+', '7'];

      case 'minor A flat':
        return ['1-', '2-', '3-', '4-', '5-', '6-', '7-'];

      case 'minor A':
        return ['1', '2', '3', '4', '5', '6', '7'];

      case 'minor A sharp':
        return ['1+', '2+', '3+', '4+', '5+', '6+', '7+'];

      case 'minor B flat':
        return ['1', '2-', '3-', '4', '5-', '6-', '7-'];

      case 'minor B':
        return ['1+', '2', '3', '4+', '5', '6', '7'];

      default:
        return ['1','2','3','4','5','6','7'];
    }
  }
}