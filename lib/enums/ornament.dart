enum Ornament {

  tremolo('tremolo','|||',
      [
        {'coeff':1/8, 'shift':0}, {'coeff':1/8, 'shift':0},{'coeff':1/8, 'shift':0}, {'coeff':1/8, 'shift':0},
        {'coeff':1/8, 'shift':0}, {'coeff':1/8, 'shift':0},{'coeff':1/8, 'shift':0}, {'coeff':1/8, 'shift':0},
      ]),

  trillDiatonic('diatonic trill','tr',
      [
        {'coeff':1/8, 'shift':0},{'coeff':1/8, 'shift':2}, {'coeff':1/8, 'shift':0},{'coeff':1/8, 'shift':2},
        {'coeff':1/8, 'shift':0}, {'coeff':1/8, 'shift':2},{'coeff':1/8, 'shift':0}, {'coeff':1/8, 'shift':2},
      ]),

  trillChromatic('chromatic trill','tr-',
      [
        {'coeff':1/8, 'shift':0}, {'coeff':1/8, 'shift':1},{'coeff':1/8, 'shift':0}, {'coeff':1/8, 'shift':1},
        {'coeff':1/8, 'shift':0}, {'coeff':1/8, 'shift':1},{'coeff':1/8, 'shift':0}, {'coeff':1/8, 'shift':1},
      ]),

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
      [{'coeff': 6/8, 'shift': 0}, {'coeff': 1/8, 'shift': -2}, {'coeff': 1/8, 'shift': 0}]),

  reversedUpperMordentFlat('reversed upper mordent flat','rUM-',
      [{'coeff': 6/8, 'shift': 0}, {'coeff': 1/8, 'shift': 1}, {'coeff': 1/8, 'shift': 0}]),
  reversedLowerMordentFlat('reversed lower mordent flat','rLM-',
      [{'coeff': 6/8, 'shift': 0}, {'coeff': 1/8, 'shift': -3}, {'coeff': 1/8, 'shift': 0}]),

  reversedUpperMordentSharp('reversed upper mordent sharp','rUM+',
      [{'coeff': 6/8, 'shift': 0}, {'coeff': 1/8, 'shift': 3}, {'coeff': 1/8, 'shift': 0}]),
  reversedLowerMordentSharp('reversed lower mordent sharp','rLM+',
      [{'coeff': 6/8, 'shift': 0}, {'coeff': 1/8, 'shift': -1}, {'coeff': 1/8, 'shift': 0}]),



  upperGruppetto('upper gruppetto','UG',
    [{'coeff':1/4, 'shift':2}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-2}, {'coeff':1/4, 'shift':0}]),
  lowerGruppetto('lower gruppetto','LG',
      [{'coeff':1/4, 'shift':-2}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':2}, {'coeff':1/4, 'shift':0}]),


  upperGruppetto1Flat('upper gruppetto 1st flat','UG -x',
    [{'coeff':1/4, 'shift':1}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-2}, {'coeff':1/4, 'shift':0}]),
  lowerGruppetto1Flat('lower gruppetto 1st flat','LG -x',
      [{'coeff':1/4, 'shift':-3}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':2}, {'coeff':1/4, 'shift':0}]),

  upperGruppetto1Sharp('upper gruppetto 1st sharp','UG +x',
    [{'coeff':1/4, 'shift':3}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-2}, {'coeff':1/4, 'shift':0}]),
  lowerGruppetto1Sharp('lower gruppetto 1st sharp','LG +x',
      [{'coeff':1/4, 'shift':-1}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':2}, {'coeff':1/4, 'shift':0}]),

  upperGruppetto2Flat('upper gruppetto 2nd flat','UG x-',
    [{'coeff':1/4, 'shift':2}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-3}, {'coeff':1/4, 'shift':0}]),
  lowerGruppetto2Flat('lower gruppetto 2nd flat','LG x-',
      [{'coeff':1/4, 'shift':-2}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':1}, {'coeff':1/4, 'shift':0}]),

  upperGruppetto2Sharp('upper gruppetto 2nd sharp','UG x+',
      [{'coeff':1/4, 'shift':2}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-1}, {'coeff':1/4, 'shift':0}]),
  lowerGruppetto2Sharp('lower gruppetto 2nd sharp','LG x+',
      [{'coeff':1/4, 'shift':-2}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':3}, {'coeff':1/4, 'shift':0}]),

  upperGruppettoFlatSharp('upper gruppetto flat sharp','UG -+',
    [{'coeff':1/4, 'shift':1}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-1}, {'coeff':1/4, 'shift':0}]),
  lowerGruppettoFlatSharp('lower gruppetto flat sharp','LG -+',
      [{'coeff':1/4, 'shift':-3}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':3}, {'coeff':1/4, 'shift':0}]),

  upperGruppettoSharpFlat('upper gruppetto sharp flat','UG +-',
    [{'coeff':1/4, 'shift':3}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-3}, {'coeff':1/4, 'shift':0}]),
  lowerGruppettoSharpFlat('lower gruppetto sharp flat','LG +-',
      [{'coeff':1/4, 'shift':-1}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':1}, {'coeff':1/4, 'shift':0}]),

  upperGruppettoFlatFlat('upper gruppetto flat flat','UG --',
    [{'coeff':1/4, 'shift':1}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-3}, {'coeff':1/4, 'shift':0}]),
  lowerGruppettoFlatFlat('lower gruppetto flat flat','LG --',
      [{'coeff':1/4, 'shift':-3}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':1}, {'coeff':1/4, 'shift':0}]),

  upperGruppettoSharpSharp('upper gruppetto sharp sharp','UG ++',
    [{'coeff':1/4, 'shift':3}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-1}, {'coeff':1/4, 'shift':0}]),
  lowerGruppettoSharpSharp('lower gruppetto sharp sharp','LG ++',
    [{'coeff':1/4, 'shift':-1}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':3}, {'coeff':1/4, 'shift':0}]),

  betweenUpperGruppetto('between upper gruppetto','bUG',
      [{'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':2}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-2}]),
  betweenLowerGruppetto('between lower gruppetto','bLG',
      [{'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-2}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':2}]),

  betweenUpperGruppettoFlat('between upper gruppetto flat','bUG -x',
      [{'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':1}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-2}]),
  betweenLowerGruppettoFlat('between lower gruppetto flat','bLG -x',
      [{'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-3}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':2}]),

  betweenUpperGruppettoSharp('between upper gruppetto sharp','bUG +x',
      [{'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':3}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-2}]),
  betweenLowerGruppettoSharp('between lower gruppetto sharp','bLG +x',
      [{'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-1}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':2}]),

  betweenUpperGruppetto2Flat('between upper gruppetto 2nd flat','bUG x-',
      [{'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':2}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-3}]),
  betweenLowerGruppetto2Flat('between lower gruppetto 2nd flat','bLG x-',
      [{'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-2}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':1}]),

  betweenUpperGruppetto2Sharp('between upper gruppetto 2nd sharp','bUG x+',
      [{'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':2}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-1}]),
  betweenLowerGruppetto2Sharp('between lower gruppetto 2nd sharp','bLG x+',
      [{'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-2}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':3}]),

  betweenUpperGruppettoFlatFlat('between upper gruppetto flat flat','BUG --',
      [{'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':1}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-3}]),
  betweenLowerGruppettoFlatFlat('between lower gruppetto flat flat','BLG --',
      [{'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-3}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':1}]),

  betweenUpperGruppettoSharpSharp('between upper gruppetto sharp sharp','bUG ++',
      [{'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':3}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-1}]),
  betweenLowerGruppettoSharpSharp('between lower gruppetto sharp sharp','bLG ++',
      [{'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-1}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':3}]),

  betweenUpperGruppettoFlatSharp('between upper gruppetto flat sharp','bUG -+',
      [{'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':1}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-1}]),
  betweenLowerGruppettoFlatSharp('between lower gruppetto flat sharp','bLG -+',
      [{'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-3}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':3}]),

  betweenUpperGruppettoSharpFlat('between upper gruppetto sharp flat','bUG +-',
      [{'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':3}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-3}]),
  betweenLowerGruppettoSharpFlat('between lower gruppetto sharp flat','bLG +-',
      [{'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':-1}, {'coeff':1/4, 'shift':0}, {'coeff':1/4, 'shift':1}]),

  // apoggiaturaDiatonic('diatonic appoggiatura','Apg',
  //     [{'coeff': 1/2, 'shift': 2}, {'coeff': 1/2, 'shift': 0}]),
  // apoggiaturaChromatic('chromatic appoggiatura','Apg-',
  //     [{'coeff': 1/2, 'shift': 1}, {'coeff': 1/2, 'shift': 0}]),
  //
  // acciaccaturaDiatonic('diatonic acciaccatura','Acc',
  //     [{'coeff': 1/8, 'shift': 2}, {'coeff': 7/8, 'shift': 0}]),
  // acciaccaturaChromatic('chromatic acciaccatura','Acc-',
  //     [{'coeff': 1/8, 'shift': 1}, {'coeff': 7/8, 'shift': 0}]),

;


  final String label;
  final String sign;
  final List shiftMap;
  const Ornament(this.label, this.sign, this.shiftMap);
}