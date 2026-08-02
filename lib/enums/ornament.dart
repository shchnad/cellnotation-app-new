enum Ornament {

  upperMordent('upper mordent','uM',
      [{'coeff': 1/8, 'shift': 0}, {'coeff': 1/8, 'shift': 2}, {'coeff': 6/8, 'shift': 0}]),
  upperMordentWithFlat('upper mordent with flat','uM-',
      [{'coeff': 1/8, 'shift': 0}, {'coeff': 1/8, 'shift': 1}, {'coeff': 6/8, 'shift': 0}]),
  upperMordentWithSharp('upper mordent with sharp','uM+',
      [{'coeff': 1/8, 'shift': 0}, {'coeff': 1/8, 'shift': 3}, {'coeff': 6/8, 'shift': 0}]),

  lowerMordent('lower mordent','lM',
      [{'coeff': 1/8, 'shift': 0}, {'coeff': 1/8, 'shift': -2}, {'coeff': 6/8, 'shift': 0}]),
  lowerMordentWithFlat('lower mordent with flat','lM-',
      [{'coeff': 1/8, 'shift': 0}, {'coeff': 1/8, 'shift': -3}, {'coeff': 6/8, 'shift': 0}]),
  lowerMordentWithSharp('lower mordent with sharp','lM+',
      [{'coeff': 1/8, 'shift': 0}, {'coeff': 1/8, 'shift': -1}, {'coeff': 6/8, 'shift': 0}]),

  reversedUpperMordent('reversed upper mordent','ruM',
      [{'coeff': 6/8, 'shift': 0}, {'coeff': 1/8, 'shift': 2}, {'coeff': 1/8, 'shift': 0}]),
  reversedUpperMordentWithFlat('reversed upper mordent with flat','ruM+',
      [{'coeff': 6/8, 'shift': 0}, {'coeff': 1/8, 'shift': 1}, {'coeff': 1/8, 'shift': 0}]),
  reversedUpperMordentWithSharp('reversed upper mordent with sharp','ruM-',
      [{'coeff': 6/8, 'shift': 0}, {'coeff': 1/8, 'shift': 3}, {'coeff': 1/8, 'shift': 0}]),

  reversedLowerMordent('reversed lower mordent','rlM',
      [{'coeff': 6/8, 'shift': 0}, {'coeff': 1/8, 'shift': -2}, {'coeff': 6/8, 'shift': 0}]),
  reversedLowerMordentWithFlat('reversed lower mordent with flat','rlM-',
      [{'coeff': 6/8, 'shift': 0}, {'coeff': 1/8, 'shift': -3}, {'coeff': 6/8, 'shift': 0}]),
  reversedLerMordentWithSharp('reversed lower mordent with sharp','rlM+',
      [{'coeff': 6/8, 'shift': 0}, {'coeff': 1/8, 'shift': -1}, {'coeff': 6/8, 'shift': 0}]),

  // may be do not really need it as it is just an added note

  apoggiaturaDiatonic('diatonic appoggiatura','apg',
      [{'coeff': 1/2, 'shift': 2}, {'coeff': 1/2, 'shift': 0}]),
  apoggiaturaChromatic('chromatic appoggiatura','apg-',
      [{'coeff': 1/2, 'shift': 1}, {'coeff': 1/2, 'shift': 0}]),

  acciaccaturaDiatonic('diatonic acciaccatura','acc',
      [{'coeff': 1/8, 'shift': 2}, {'coeff': 7/8, 'shift': 0}]),
  acciaccaturaChromatic('chromatic acciaccatura','acc-',
      [{'coeff': 1/8, 'shift': 1}, {'coeff': 7/8, 'shift': 0}]),

  upperGrupetto('upper grupetto','uGx/x',
    [{'coeff':1/4, 'shift':2}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-2}, {'coeff':1/4, 'shift':0}]),
  upperGrupetto1Flat('upper grupetto 1st note flat','uG-/x',
    [{'coeff':1/4, 'shift':1}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-2}, {'coeff':1/4, 'shift':0}]),
  upperGrupetto1Sharp('upper grupetto 1st note sharp','uG+/x',
    [{'coeff':1/4, 'shift':3}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-2}, {'coeff':1/4, 'shift':0}]),
  upperGrupetto2Flat('upper grupetto 2nd note flat','uGx/-',
    [{'coeff':1/4, 'shift':2}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-1}, {'coeff':1/4, 'shift':0}]),
  upperGrupetto2Sharp('upper grupetto 2nd note sharp','uGx/+',
    [{'coeff':1/4, 'shift':2}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-1}, {'coeff':1/4, 'shift':0}]),
  upperGrupettoFlatSharp('upper grupetto flat sharp','uG-/+',
    [{'coeff':1/4, 'shift':1}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-1}, {'coeff':1/4, 'shift':0}]),
  upperGrupettoSharpFlat('upper grupetto sharp flat','uG+/-',
    [{'coeff':1/4, 'shift':3}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-3}, {'coeff':1/4, 'shift':0}]),
  upperGrupettoFlatFlat('upper grupetto flat flat','uG-/-',
    [{'coeff':1/4, 'shift':1}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-3}, {'coeff':1/4, 'shift':0}]),
  upperGrupettoSharpSharp('upper grupetto sharp sharp','uG+/+',
    [{'coeff':1/4, 'shift':3}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-1}, {'coeff':1/4, 'shift':0}]),

  lowerGrupetto('lower grupetto','lGx/x',
    [{'coeff':1/4, 'shift':-2}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':2}, {'coeff':1/4, 'shift':0}]),
  lowerGrupettoFlat('lower grupetto flat','lG-/x',
    [{'coeff':1/4, 'shift':-3}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':2}, {'coeff':1/4, 'shift':0}]),
  lowerGrupettoSharp('lower grupetto sharp','lG+/x',
    [{'coeff':1/4, 'shift':-1}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':2}, {'coeff':1/4, 'shift':0}]),
  lowerGrupetto2Flat('lower grupetto 2nd note flat','lGx/-',
    [{'coeff':1/4, 'shift':-2}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':1}, {'coeff':1/4, 'shift':0}]),
  lowerGrupetto2Sharp('lower grupetto flat','lGx/+',
    [{'coeff':1/4, 'shift':-2}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':3}, {'coeff':1/4, 'shift':0}]),
  lowerGrupettoFlatSharp('lower grupetto flat sharp','lG-/+',
    [{'coeff':1/4, 'shift':-3}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':3}, {'coeff':1/4, 'shift':0}]),
  lowerGrupettoSharpFlat('lower grupetto sharp flat','lG+/-',
    [{'coeff':1/4, 'shift':-1}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':1}, {'coeff':1/4, 'shift':0}]),
  lowerGrupettoSharpSharp('lower grupetto sharp sharp','lG+/+',
    [{'coeff':1/4, 'shift':-1}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':3}, {'coeff':1/4, 'shift':0}]),
  lowerGrupettoFlatFlat('lower grupetto flat flat','lG-/-',
    [{'coeff':1/4, 'shift':-3}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':1}, {'coeff':1/4, 'shift':0}]),


  trillDiatonic('diatonic trill','tr',
      [
        {'coeff':1/32, 'shift':2}, {'coeff':1/32, 'shift':0},{'coeff':1/32, 'shift':2}, {'coeff':1/32, 'shift':0},
        {'coeff':1/32, 'shift':2}, {'coeff':1/32, 'shift':0},{'coeff':1/32, 'shift':2}, {'coeff':1/32, 'shift':0},
        {'coeff':1/32, 'shift':2}, {'coeff':1/32, 'shift':0},{'coeff':1/32, 'shift':2}, {'coeff':1/32, 'shift':0},
        {'coeff':1/32, 'shift':2}, {'coeff':1/32, 'shift':0},{'coeff':1/32, 'shift':2}, {'coeff':1/32, 'shift':0}
      ]),

  trillChromatic('chromatic trill','tr-',
      [
      {'coeff':1/32, 'shift':1}, {'coeff':1/32, 'shift':0},{'coeff':1/32, 'shift':1}, {'coeff':1/32, 'shift':0},
      {'coeff':1/32, 'shift':1}, {'coeff':1/32, 'shift':0},{'coeff':1/32, 'shift':1}, {'coeff':1/32, 'shift':0},
      {'coeff':1/32, 'shift':1}, {'coeff':1/32, 'shift':0},{'coeff':1/32, 'shift':1}, {'coeff':1/32, 'shift':0},
      {'coeff':1/32, 'shift':1}, {'coeff':1/32, 'shift':0},{'coeff':1/32, 'shift':1}, {'coeff':1/32, 'shift':0}
      ]),

  tremolo('tremolo','|||',
      [
        {'coeff':1/32, 'shift':0}, {'coeff':1/32, 'shift':0},{'coeff':1/32, 'shift':0}, {'coeff':1/32, 'shift':0},
        {'coeff':1/32, 'shift':0}, {'coeff':1/32, 'shift':0},{'coeff':1/32, 'shift':0}, {'coeff':1/32, 'shift':0},
        {'coeff':1/32, 'shift':0}, {'coeff':1/32, 'shift':0},{'coeff':1/32, 'shift':0}, {'coeff':1/32, 'shift':0},
        {'coeff':1/32, 'shift':0}, {'coeff':1/32, 'shift':0},{'coeff':1/32, 'shift':0}, {'coeff':1/32, 'shift':0}
      ]);


  final String label;
  final String sign;
  final List shiftMap;
  const Ornament(this.label, this.sign, this.shiftMap);
}