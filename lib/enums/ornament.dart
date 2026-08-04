enum Ornament {

  upperMordent('upper mordent','UM',
      [{'coeff': 1/8, 'shift': 0}, {'coeff': 1/8, 'shift': 2}, {'coeff': 6/8, 'shift': 0}]),
  lowerMordent('lower mordent','LM',
      [{'coeff': 1/8, 'shift': 0}, {'coeff': 1/8, 'shift': -2}, {'coeff': 6/8, 'shift': 0}]),

  upperMordentFlat('upper mordent flat','UM-',
      [{'coeff': 1/8, 'shift': 0}, {'coeff': 1/8, 'shift': 1}, {'coeff': 6/8, 'shift': 0}]),
  lowerMordentFlat('lower mordent flat','LM-',
      [{'coeff': 1/8, 'shift': 0}, {'coeff': 1/8, 'shift': -3}, {'coeff': 6/8, 'shift': 0}]),

  upperMordentSharp('upper mordent sharp','UM+',
      [{'coeff': 1/8, 'shift': 0}, {'coeff': 1/8, 'shift': 3}, {'coeff': 6/8, 'shift': 0}]),
  lowerMordentSharp('lower mordent sharp','LM+',
      [{'coeff': 1/8, 'shift': 0}, {'coeff': 1/8, 'shift': -1}, {'coeff': 6/8, 'shift': 0}]),

  reversedUpperMordent('reversed upper mordent','rUM',
      [{'coeff': 6/8, 'shift': 0}, {'coeff': 1/8, 'shift': 2}, {'coeff': 1/8, 'shift': 0}]),
  reversedLowerMordent('reversed lower mordent','rLM',
      [{'coeff': 6/8, 'shift': 0}, {'coeff': 1/8, 'shift': -2}, {'coeff': 6/8, 'shift': 0}]),

  reversedUpperMordentFlat('reversed upper mordent flat','rUM-',
      [{'coeff': 6/8, 'shift': 0}, {'coeff': 1/8, 'shift': 1}, {'coeff': 1/8, 'shift': 0}]),
  reversedLowerMordentFlat('reversed lower mordent flat','rLM-',
      [{'coeff': 6/8, 'shift': 0}, {'coeff': 1/8, 'shift': -3}, {'coeff': 6/8, 'shift': 0}]),

  reversedUpperMordentSharp('reversed upper mordent sharp','rUM+',
      [{'coeff': 6/8, 'shift': 0}, {'coeff': 1/8, 'shift': 3}, {'coeff': 1/8, 'shift': 0}]),
  reversedLowerMordentSharp('reversed lower mordent sharp','rLM+',
      [{'coeff': 6/8, 'shift': 0}, {'coeff': 1/8, 'shift': -1}, {'coeff': 6/8, 'shift': 0}]),


  upperGrupetto('upper grupetto','UG',
    [{'coeff':1/4, 'shift':2}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-2}, {'coeff':1/4, 'shift':0}]),
  lowerGrupetto('lower grupetto','LG',
      [{'coeff':1/4, 'shift':-2}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':2}, {'coeff':1/4, 'shift':0}]),


  upperGrupetto1Flat('upper grupetto 1st flat','UG-/x',
    [{'coeff':1/4, 'shift':1}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-2}, {'coeff':1/4, 'shift':0}]),
  lowerGrupetto1Flat('lower grupetto 1st flat','LG-/x',
      [{'coeff':1/4, 'shift':-3}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':2}, {'coeff':1/4, 'shift':0}]),

  upperGrupetto1Sharp('upper grupetto 1st sharp','UG+/x',
    [{'coeff':1/4, 'shift':3}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-2}, {'coeff':1/4, 'shift':0}]),
  lowerGrupetto1Sharp('lower grupetto 1st sharp','LG+/x',
      [{'coeff':1/4, 'shift':-1}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':2}, {'coeff':1/4, 'shift':0}]),

  upperGrupetto2Flat('upper grupetto 2nd flat','UGx/-',
    [{'coeff':1/4, 'shift':2}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-1}, {'coeff':1/4, 'shift':0}]),
  lowerGrupetto2Flat('lower grupetto 2nd flat','LGx/-',
      [{'coeff':1/4, 'shift':-2}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':1}, {'coeff':1/4, 'shift':0}]),

  upperGrupetto2Sharp('upper grupetto 2nd sharp','UGx/+',
      [{'coeff':1/4, 'shift':2}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-1}, {'coeff':1/4, 'shift':0}]),
  lowerGrupetto2Sharp('lower grupetto 2nd flat','LGx/+',
      [{'coeff':1/4, 'shift':-2}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':3}, {'coeff':1/4, 'shift':0}]),

  upperGrupettoFlatSharp('upper grupetto flat sharp','UG-/+',
    [{'coeff':1/4, 'shift':1}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-1}, {'coeff':1/4, 'shift':0}]),
  lowerGrupettoFlatSharp('lower grupetto flat sharp','LG-/+',
      [{'coeff':1/4, 'shift':-3}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':3}, {'coeff':1/4, 'shift':0}]),

  upperGrupettoSharpFlat('upper grupetto sharp flat','UG+/-',
    [{'coeff':1/4, 'shift':3}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-3}, {'coeff':1/4, 'shift':0}]),
  lowerGrupettoSharpFlat('lower grupetto sharp flat','LG+/-',
      [{'coeff':1/4, 'shift':-1}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':1}, {'coeff':1/4, 'shift':0}]),

  upperGrupettoFlatFlat('upper grupetto flat flat','UG-/-',
    [{'coeff':1/4, 'shift':1}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-3}, {'coeff':1/4, 'shift':0}]),
  lowerGrupettoFlatFlat('lower grupetto flat flat','LG-/-',
      [{'coeff':1/4, 'shift':-3}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':1}, {'coeff':1/4, 'shift':0}]),

  upperGrupettoSharpSharp('upper grupetto sharp sharp','UG+/+',
    [{'coeff':1/4, 'shift':3}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-1}, {'coeff':1/4, 'shift':0}]),
  lowerGrupettoSharpSharp('lower grupetto sharp sharp','LG+/+',
    [{'coeff':1/4, 'shift':-1}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':3}, {'coeff':1/4, 'shift':0}]),

  trillDiatonic('diatonic trill','tr',
      [
        {'coeff':1/8, 'shift':2}, {'coeff':1/8, 'shift':0},{'coeff':1/8, 'shift':2}, {'coeff':1/8, 'shift':0},
        {'coeff':1/8, 'shift':2}, {'coeff':1/8, 'shift':0},{'coeff':1/8, 'shift':2}, {'coeff':1/8, 'shift':0},
      ]),

  trillChromatic('chromatic trill','tr-',
      [
        {'coeff':1/8, 'shift':1}, {'coeff':1/8, 'shift':0},{'coeff':1/8, 'shift':1}, {'coeff':1/8, 'shift':0},
        {'coeff':1/8, 'shift':1}, {'coeff':1/8, 'shift':0},{'coeff':1/8, 'shift':1}, {'coeff':1/8, 'shift':0},
      ]),

  // apoggiaturaDiatonic('diatonic appoggiatura','Apg',
  //     [{'coeff': 1/2, 'shift': 2}, {'coeff': 1/2, 'shift': 0}]),
  // apoggiaturaChromatic('chromatic appoggiatura','Apg-',
  //     [{'coeff': 1/2, 'shift': 1}, {'coeff': 1/2, 'shift': 0}]),
  //
  // acciaccaturaDiatonic('diatonic acciaccatura','Acc',
  //     [{'coeff': 1/8, 'shift': 2}, {'coeff': 7/8, 'shift': 0}]),
  // acciaccaturaChromatic('chromatic acciaccatura','Acc-',
  //     [{'coeff': 1/8, 'shift': 1}, {'coeff': 7/8, 'shift': 0}]),

  tremolo('tremolo','|||',
      [
        {'coeff':1/8, 'shift':0}, {'coeff':1/8, 'shift':0},{'coeff':1/8, 'shift':0}, {'coeff':1/8, 'shift':0},
        {'coeff':1/8, 'shift':0}, {'coeff':1/8, 'shift':0},{'coeff':1/8, 'shift':0}, {'coeff':1/8, 'shift':0},
      ]);


  final String label;
  final String sign;
  final List shiftMap;
  const Ornament(this.label, this.sign, this.shiftMap);
}