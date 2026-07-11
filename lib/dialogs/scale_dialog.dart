import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';



class ScaleDialog extends StatefulWidget {

  final CompositionController controller;


  const ScaleDialog({
    super.key,
    required this.controller,
  });


  @override
  State<ScaleDialog> createState() =>
      _ScaleDialogState();

}

class _ScaleDialogState extends State<ScaleDialog> {
  late String _activeScale;

  @override
  void initState() {
    super.initState();


    if (widget.controller.measures.isNotEmpty) {
      _activeScale =  widget.controller.currentMeasure.scaleName;
    } else {
      _activeScale = 'major C';
    }
  }


  void _updateScale(String newScaleName) {
    setState(() {
      _activeScale = newScaleName;
    });
    widget.controller.updateCurrentMeasureScale(newScaleName);
  }


  @override
  Widget build(BuildContext context) {

    final currentMeasureNumber = widget.controller.selectedMeasureIndex + 1;
    return AlertDialog(
      title: Text(
        'Set Scale for Measure $currentMeasureNumber',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 350,
        child: Column(
          children: [
            Text(
              'Active: $_activeScale',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
            const Divider(),
            Expanded(
              child: GridView.builder(
                itemCount: widget.controller.availableScales.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.8,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (context,index){
                  final scaleName = widget.controller.availableScales[index];
                  final selected = scaleName == _activeScale;
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                     backgroundColor: selected
                          ? Colors.blue
                          : Colors.grey[200],
                      foregroundColor: selected
                          ? Colors.white
                          : Colors.black87,
                    ),
                    onPressed:
                        () => _updateScale(
                        scaleName
                    ),
                   child: Text(
                      scaleName,
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              () => Navigator.pop(context),
          child: const Text(
              'Done'
          ),
        ),
      ],
    );
  }
}