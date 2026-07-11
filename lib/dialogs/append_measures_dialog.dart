import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';

import '../models/composition.dart';
import '../models/time_signature.dart';

import '../enums/note_duration.dart';

import 'note_values_dialog.dart';



class AppendMeasuresDialog extends StatefulWidget {

  final Composition targetComposition;
  final CompositionController controller;
  final VoidCallback onMeasuresAppended;


  const AppendMeasuresDialog({
    super.key,
    required this.targetComposition,
    required this.controller,
    required this.onMeasuresAppended,
  });

  @override
  State<AppendMeasuresDialog> createState() =>
      _AppendMeasuresDialogState();
}

class _AppendMeasuresDialogState
    extends State<AppendMeasuresDialog> {

  final _formKey = GlobalKey<FormState>();
  final _measuresController = TextEditingController(text: '1');
  int _beatsPerMeasure = 4;
  NoteDuration _selectedBeatUnit =  NoteDuration.quarter;
  late String _selectedScale;


  @override
  void initState() {
    super.initState();

    if(widget.controller.measures.isNotEmpty){
      _selectedScale =  widget.controller.measures.last.scaleName;
    } else {
      _selectedScale = 'major C';
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
        alignment: Alignment.topCenter,
        insetPadding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 12
        ),
        title: const Text(
          'Configure Measures',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * .5,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSelectionField(
                  label: 'Scale Key',
                  valueText: scaleDisplayLabel,
                  icon: Icons.music_note,
                  onTap: (){
                    noteValuesDialog<String>(
                      context: context,
                      title:'Select Scale Key',
                      currentValue: _selectedScale,
                      values: widget.controller.availableScales,
                      labelBuilder:(scale)=>scale,
                      numberOfColumns: 2,
                      onSelected: (scale){
                        setState((){
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Colors.grey.shade400
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Time Signature',
                        style: TextStyle(
                          fontWeight:
                          FontWeight.bold,
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
                                        ),
                                      )
                              )
                                  .toList(),
                              onChanged: (value){
                                setState((){
                                  _beatsPerMeasure = value ?? 4;
                                });
                              },
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8
                            ),
                            child: Text(
                              '/',
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
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
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
          TextButton(
            onPressed:
                ()=>Navigator.pop(context),
            child: const Text(
                'Cancel'
            ),
          ),
          ElevatedButton(
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
                'Generate'
            ),
          ),
        ],
      ),
    );
  }
}