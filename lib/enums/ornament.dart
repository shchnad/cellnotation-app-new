enum Ornament {

  upperMordent('upper mordent','UM',
      [{'coeff': 1/8, 'shift': 0}, {'coeff': 1/8, 'shift': 2}, {'coeff': 6/8, 'shift': 0}]),
  upperMordentWithFlat('upper mordent with flat','UM-',
      [{'coeff': 1/8, 'shift': 0}, {'coeff': 1/8, 'shift': 1}, {'coeff': 6/8, 'shift': 0}]),
  upperMordentWithSharp('upper mordent with sharp','UM+',
      [{'coeff': 1/8, 'shift': 0}, {'coeff': 1/8, 'shift': 3}, {'coeff': 6/8, 'shift': 0}]),

  lowerMordent('lower mordent','LM',
      [{'coeff': 1/8, 'shift': 0}, {'coeff': 1/8, 'shift': -2}, {'coeff': 6/8, 'shift': 0}]),
  lowerMordentWithFlat('lower mordent with flat','LM-',
      [{'coeff': 1/8, 'shift': 0}, {'coeff': 1/8, 'shift': -3}, {'coeff': 6/8, 'shift': 0}]),
  lowerMordentWithSharp('lower mordent with sharp','LM+',
      [{'coeff': 1/8, 'shift': 0}, {'coeff': 1/8, 'shift': -1}, {'coeff': 6/8, 'shift': 0}]),

  reversedUpperMordent('reversed upper mordent','rUM',
      [{'coeff': 6/8, 'shift': 0}, {'coeff': 1/8, 'shift': 2}, {'coeff': 1/8, 'shift': 0}]),
  reversedUpperMordentWithFlat('reversed upper mordent with flat','rUM-',
      [{'coeff': 6/8, 'shift': 0}, {'coeff': 1/8, 'shift': 1}, {'coeff': 1/8, 'shift': 0}]),
  reversedUpperMordentWithSharp('reversed upper mordent with sharp','rUM+',
      [{'coeff': 6/8, 'shift': 0}, {'coeff': 1/8, 'shift': 3}, {'coeff': 1/8, 'shift': 0}]),

  reversedLowerMordent('reversed lower mordent','rLM',
      [{'coeff': 6/8, 'shift': 0}, {'coeff': 1/8, 'shift': -2}, {'coeff': 6/8, 'shift': 0}]),
  reversedLowerMordentWithFlat('reversed lower mordent with flat','rLM-',
      [{'coeff': 6/8, 'shift': 0}, {'coeff': 1/8, 'shift': -3}, {'coeff': 6/8, 'shift': 0}]),
  reversedLerMordentWithSharp('reversed lower mordent with sharp','rLM+',
      [{'coeff': 6/8, 'shift': 0}, {'coeff': 1/8, 'shift': -1}, {'coeff': 6/8, 'shift': 0}]),

  // may be do not really need it as it is just an added note

  apoggiaturaDiatonic('diatonic appoggiatura','Apg',
      [{'coeff': 1/2, 'shift': 2}, {'coeff': 1/2, 'shift': 0}]),
  apoggiaturaChromatic('chromatic appoggiatura','Apg-',
      [{'coeff': 1/2, 'shift': 1}, {'coeff': 1/2, 'shift': 0}]),

  acciaccaturaDiatonic('diatonic acciaccatura','Acc',
      [{'coeff': 1/8, 'shift': 2}, {'coeff': 7/8, 'shift': 0}]),
  acciaccaturaChromatic('chromatic acciaccatura','Acc-',
      [{'coeff': 1/8, 'shift': 1}, {'coeff': 7/8, 'shift': 0}]),

  upperGrupetto('upper grupetto','UG',
    [{'coeff':1/4, 'shift':2}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-2}, {'coeff':1/4, 'shift':0}]),
  upperGrupetto1Flat('upper grupetto 1st note flat','UG-/x',
    [{'coeff':1/4, 'shift':1}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-2}, {'coeff':1/4, 'shift':0}]),
  upperGrupetto1Sharp('upper grupetto 1st note sharp','UG+/x',
    [{'coeff':1/4, 'shift':3}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-2}, {'coeff':1/4, 'shift':0}]),
  upperGrupetto2Flat('upper grupetto 2nd note flat','UGx/-',
    [{'coeff':1/4, 'shift':2}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-1}, {'coeff':1/4, 'shift':0}]),
  upperGrupetto2Sharp('upper grupetto 2nd note sharp','UGx/+',
    [{'coeff':1/4, 'shift':2}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-1}, {'coeff':1/4, 'shift':0}]),
  upperGrupettoFlatSharp('upper grupetto flat sharp','UG-/+',
    [{'coeff':1/4, 'shift':1}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-1}, {'coeff':1/4, 'shift':0}]),
  upperGrupettoSharpFlat('upper grupetto sharp flat','UG+/-',
    [{'coeff':1/4, 'shift':3}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-3}, {'coeff':1/4, 'shift':0}]),
  upperGrupettoFlatFlat('upper grupetto flat flat','UG-/-',
    [{'coeff':1/4, 'shift':1}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-3}, {'coeff':1/4, 'shift':0}]),
  upperGrupettoSharpSharp('upper grupetto sharp sharp','UG+/+',
    [{'coeff':1/4, 'shift':3}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-1}, {'coeff':1/4, 'shift':0}]),

  lowerGrupetto('lower grupetto','LG',
    [{'coeff':1/4, 'shift':-2}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':2}, {'coeff':1/4, 'shift':0}]),
  lowerGrupettoFlat('lower grupetto flat','LG-/x',
    [{'coeff':1/4, 'shift':-3}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':2}, {'coeff':1/4, 'shift':0}]),
  lowerGrupettoSharp('lower grupetto sharp','LG+/x',
    [{'coeff':1/4, 'shift':-1}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':2}, {'coeff':1/4, 'shift':0}]),
  lowerGrupetto2Flat('lower grupetto 2nd note flat','LGx/-',
    [{'coeff':1/4, 'shift':-2}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':1}, {'coeff':1/4, 'shift':0}]),
  lowerGrupetto2Sharp('lower grupetto flat','LGx/+',
    [{'coeff':1/4, 'shift':-2}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':3}, {'coeff':1/4, 'shift':0}]),
  lowerGrupettoFlatSharp('lower grupetto flat sharp','LG-/+',
    [{'coeff':1/4, 'shift':-3}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':3}, {'coeff':1/4, 'shift':0}]),
  lowerGrupettoSharpFlat('lower grupetto sharp flat','LG+/-',
    [{'coeff':1/4, 'shift':-1}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':1}, {'coeff':1/4, 'shift':0}]),
  lowerGrupettoSharpSharp('lower grupetto sharp sharp','LG+/+',
    [{'coeff':1/4, 'shift':-1}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':3}, {'coeff':1/4, 'shift':0}]),
  lowerGrupettoFlatFlat('lower grupetto flat flat','LG-/-',
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