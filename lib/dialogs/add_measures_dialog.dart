import 'package:flutter/material.dart';
import 'package:music_composer/dialogs/scale_dialog.dart';

import '../controllers/composition_controller.dart';

import '../models/composition.dart';
import '../models/time_signature.dart';

import '../enums/note_duration.dart';

import '../utils/default_values.dart';
import 'note_values_dialog.dart';



class AddMeasuresDialog extends StatefulWidget {

  final Composition targetComposition;
  final CompositionController controller;
  final VoidCallback onMeasuresAppended;


  const AddMeasuresDialog({
    super.key,
    required this.targetComposition,
    required this.controller,
    required this.onMeasuresAppended,
  });

  @override
  State<AddMeasuresDialog> createState() =>
      _AddMeasuresDialogState();
}

class _AddMeasuresDialogState extends State<AddMeasuresDialog> {

  final _formKey = GlobalKey<FormState>();

  final _measuresController = TextEditingController(
      text: DefaultValues.numberOfMeasures
  );

  int _beatsPerMeasure = DefaultValues.beatsPerMeasure;

  NoteDuration _selectedBeatUnit = DefaultValues.duration;

  late String _selectedScale;

  @override
  void initState() {
    super.initState();

    if(widget.controller.measures.isNotEmpty){
      _selectedScale =  widget.controller.measures.last.scaleName;
    } else {
      _selectedScale = DefaultValues.scale;
    }
  }

  @override
  void dispose(){
    _measuresController.dispose();
    super.dispose();
  }




  Widget _buildSelectionField({
    required String label,
    required String valueText,
    required IconData icon,
    required VoidCallback onTap,
  }){
    return InkWell(
      onTap: (){
        FocusScope.of(context).unfocus();
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10
          ),
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon),
        ),
        child: Row(
          mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
          children: [

            Expanded(
              child: Text(
                valueText,
                style: const TextStyle(
                  fontSize: 22,
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
                overflow:
                TextOverflow.ellipsis,
              ),
            ),

            const Icon(
                Icons.arrow_drop_down,
                color: Colors.blue
            ),

          ],
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {

    final parts = _selectedScale.split(' ');
    final scaleDisplayLabel = parts.length == 2
        ? '${parts[1]} ${parts[0]}'
        : parts.length > 2
          ? '${parts.sublist(1).join(' ')} ${parts[0]}'
          : _selectedScale;

    return SafeArea(
      child: AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(
          DefaultValues.dialogPaddingRightLeft,
          DefaultValues.dialogPaddingBottomTop,
          DefaultValues.dialogPaddingRightLeft,
          DefaultValues.dialogPaddingBottomTop,
        ),
        // actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        backgroundColor: Colors.white,
        alignment: Alignment.topCenter,
        title: const Text(
          'Configure Measures',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * .35,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                _buildSelectionField(
                  label: 'Scale',
                  valueText: scaleDisplayLabel,
                  icon: Icons.music_note,
                  onTap: () {
                    scaleDialog(
                      context: context,
                      controller: widget.controller,
                      currentScale: _selectedScale,
                      onSelected: (scale) {
                        setState(() {
                          _selectedScale = scale;
                        });
                      },
                    );
                  },
                ),

                const SizedBox(
                    height: 12
                ),

                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Colors.grey.shade400
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Time Signature',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                          height: 8
                      ),

                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _beatsPerMeasure,
                              items: [1,2,3,4,5,6,7,8,9,12]
                                  .map( (b)=> DropdownMenuItem(
                                        value: b,
                                        child: Text(
                                          '$b',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                            fontSize: 22,
                                          ),
                                        ),
                                      )
                              )
                                  .toList(),
                              onChanged: (value){
                                setState((){
                                  _beatsPerMeasure = value ?? DefaultValues.beatsPerMeasure;
                                });
                              },
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 5
                            ),
                            child: Text(
                              '*',
                              style: TextStyle(
                                  fontSize: 22
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: (){
                                noteValuesDialog<NoteDuration>(
                                  context:
                                  context,
                                  title: 'Beat Duration',
                                  currentValue: _selectedBeatUnit,
                                  values: NoteDuration.values,
                                  labelBuilder:(d)=>d.label,
                                  numberOfColumns: 3,
                                  onSelected: (duration){
                                    setState((){
                                      _selectedBeatUnit = duration;
                                    });
                                  },
                                );
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(
                                  _selectedBeatUnit.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                    fontSize: 22,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                    height: 12
                ),
                TextFormField(
                  controller: _measuresController,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    fontSize: 22,
                  ),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Measures to Add',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value){
                    final n = int.tryParse(value ?? '');
                    if(n == null || n <= 0){
                      return 'Enter amount';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          Row(
            children: [
              SizedBox(
                width: DefaultValues.widthOfElevatedButton,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  onPressed:
                      ()=>Navigator.pop(context),
                  child: const Text(
                      'Cancel',
                    style: TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: DefaultValues.widthOfElevatedButton,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  onPressed: (){
                    if(!_formKey.currentState!
                        .validate()){
                      return;
                    }
                    final count = int.parse(
                        _measuresController.text
                    );
                    for(int i=0;i<count;i++){
                      widget.controller.addMeasure(
                        TimeSignature(
                          beats: _beatsPerMeasure,
                          beatDuration: _selectedBeatUnit,
                        ),
                        _selectedScale,
                      );
                    }
                    widget.onMeasuresAppended();
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Generate',
                    style: TextStyle(fontSize: 22),
                  ),
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }
}