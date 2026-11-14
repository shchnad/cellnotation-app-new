import 'package:flutter/material.dart';

import '../controllers/composition_controller.dart';

/// Repeats (reprises). Four kinds can be set:
///  1. Simple reprise — 𝄆 … 𝄇 around a range of measures.
///  2. Reprise with voltas — 𝄆 … volta 1 𝄇, then volta 2.
///  3. D.S. al Fine — 𝄋 Segno, Fine and D.S. al Fine.
///  4. D.S. al Coda — 𝄋 Segno, To Coda, D.S. al Coda and Coda.
///
/// In edit mode only the signs are shown. In playback mode (Scroll
/// Lock on) the repeated measures are inserted as temporary copies with
/// red numbers, and removed again when going back to edit mode.
Future<void> repeatsDialog(BuildContext context, CompositionController controller) {
  return showDialog(
    context: context,
    builder: (_) => _RepeatsDialog(controller: controller),
  );
}

class _RepeatsDialog extends StatefulWidget {
  final CompositionController controller;
  const _RepeatsDialog({required this.controller});

  @override
  State<_RepeatsDialog> createState() => _RepeatsDialogState();
}

/// One measure-number box of the dialog.
class _Field {
  final String label;
  final TextEditingController text = TextEditingController();
  _Field(this.label);

  /// The 0-based measure position typed (null when empty or not a number).
  int? get index {
    final n = int.tryParse(text.text.trim());
    return n == null ? null : n - 1;
  }
}

class _RepeatsDialogState extends State<_RepeatsDialog> {
  CompositionController get c => widget.controller;

  RepriseType _type = RepriseType.simple;

  final _simple = [_Field('Start measure'), _Field('End measure')];
  final _voltas = [
    _Field('Start measure'),
    _Field('start'),
    _Field('end'),
    _Field('start'),
    _Field('end'),
  ];
  final _segnoFine = [
    _Field('𝄋 or "Segno" is on measure number'),
    _Field('"Fine" is on measure number'),
    _Field('"D.S. al Fine" is on measure number'),
  ];
  final _segnoCoda = [
    _Field('𝄋 or "Segno" is on measure number'),
    _Field('"To Coda" or "Da Coda" is on measure number'),
    _Field('"D.S. al Coda" is on measure number'),
    _Field('"Coda" is on measure number'),
  ];

  List<_Field> get _fields {
    switch (_type) {
      case RepriseType.simple:
        return _simple;
      case RepriseType.voltas:
        return _voltas;
      case RepriseType.segnoFine:
        return _segnoFine;
      case RepriseType.segnoCoda:
        return _segnoCoda;
    }
  }

  @override
  void initState() {
    super.initState();
    // Start from the measure the person last tapped.
    final n = c.measures.length;
    final selected = (c.selectedMeasureIndex.clamp(0, n > 0 ? n - 1 : 0) + 1).toString();
    _simple[0].text.text = selected;
    _voltas[0].text.text = selected;
    // Volta 2 starts right after volta 1 — filled in automatically.
    _voltas[2].text.addListener(() {
      final i = _voltas[2].index;
      if (i != null) _voltas[3].text.text = '${i + 2}';
    });
    _segnoCoda[2].text.addListener(() {
      final i = _segnoCoda[2].index;
      if (i != null && _segnoCoda[3].text.text.isEmpty) {
        _segnoCoda[3].text.text = '${i + 2}';
      }
    });
  }

  @override
  void dispose() {
    for (final f in [..._simple, ..._voltas, ..._segnoFine, ..._segnoCoda]) {
      f.text.dispose();
    }
    super.dispose();
  }

  String _typeName(RepriseType t) {
    switch (t) {
      case RepriseType.simple:
        return 'Simple reprise  𝄆 𝄇';
      case RepriseType.voltas:
        return 'Reprise with voltas  1. 2.';
      case RepriseType.segnoFine:
        return 'Reprise 𝄋 Segno al Fine';
      case RepriseType.segnoCoda:
        return 'Reprise 𝄋 Segno al Coda';
    }
  }

  String _describe(Reprise r) {
    String m(int? i) => i == null ? '?' : '${i + 1}';
    switch (r.type) {
      case RepriseType.simple:
        return 'Measures ${m(r.start)}–${m(r.end)}';
      case RepriseType.voltas:
        return 'Measures ${m(r.start)}–${m(r.end)}, volta 1: '
            '${m(r.volta1Start)}–${m(r.end)}, volta 2: '
            '${(r.end ?? 0) + 2}–${m(r.volta2End)}';
      case RepriseType.segnoFine:
        return 'Segno ${m(r.segno)}, Fine ${m(r.fine)}, D.S. ${m(r.dalSegno)}';
      case RepriseType.segnoCoda:
        return 'Segno ${m(r.segno)}, To Coda ${m(r.toCoda)}, '
            'D.S. ${m(r.dalSegno)}, Coda ${m(r.coda)}';
    }
  }

  void _add() {
    final values = [for (final f in _fields) f.index];
    if (values.any((v) => v == null)) {
      _message('Fill in every measure number.');
      return;
    }
    final v = values.cast<int>();
    String? error;
    switch (_type) {
      case RepriseType.simple:
        error = c.addSimpleReprise(v[0], v[1]);
        break;
      case RepriseType.voltas:
        error = c.addVoltaReprise(v[0], v[1], v[2], v[3], v[4]);
        break;
      case RepriseType.segnoFine:
        error = c.addSegnoFine(v[0], v[1], v[2]);
        break;
      case RepriseType.segnoCoda:
        error = c.addSegnoCoda(v[0], v[1], v[2], v[3]);
        break;
    }
    if (error != null) {
      _message(error);
      return;
    }
    setState(() {
      for (final f in _fields) {
        f.text.clear();
      }
    });
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(text, style: const TextStyle(fontSize: 22)),
      ),
    );
  }

  /// One measure-number box; [label] (e.g. "start") stays shown above
  /// the number.
  Widget _box(_Field f, {String? label}) {
    return SizedBox(
      width: 110,
      child: TextField(
        controller: f.text,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 22,
          color: Colors.blue,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          isDense: true,
          border: const OutlineInputBorder(),
          labelText: label,
          labelStyle: const TextStyle(fontSize: 22, color: Colors.black54),
          floatingLabelBehavior: FloatingLabelBehavior.always,
        ),
      ),
    );
  }

  /// A volta on one row: its name, then a start box and an end box.
  Widget _rangeRow(String name, _Field start, _Field end) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(name, style: const TextStyle(fontSize: 22, color: Colors.black)),
          ),
          _box(start, label: 'start'),
          const SizedBox(width: 12),
          _box(end, label: 'end'),
        ],
      ),
    );
  }

  Widget _numberField(_Field f) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(f.label, style: const TextStyle(fontSize: 22, color: Colors.black)),
          ),
          SizedBox(
            width: 110,
            child: TextField(
              controller: f.text,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locked = c.playbackExpanded;
    final existing = locked ? const <Reprise>[] : c.reprises;
    return AlertDialog(
      alignment: Alignment.topCenter,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: const Text(
        'Repeats',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.70,
          child: locked
              ? const Text(
            'Repeats can be set in edit mode only. Turn off Scroll '
                'Lock first — the repeated measures added for playback '
                'are then removed and the signs come back.',
            style: TextStyle(fontSize: 22, color: Colors.black),
          )
              : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The composition has ${c.measures.length} '
                    'measure${c.measures.length == 1 ? '' : 's'}.',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
              ),
              const SizedBox(height: 10),
              // Repeats already set.
              if (existing.isEmpty)
                const Text('No repeats set yet.',
                    style: TextStyle(fontSize: 22, color: Colors.black54))
              else
                for (final r in existing)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.repeat,
                        color: Color(0xFFE65100), size: 28),
                    title: Text(_typeName(r.type),
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    subtitle: Text(_describe(r),
                        style: const TextStyle(fontSize: 22)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 28),
                      tooltip: 'Remove',
                      onPressed: () => setState(() => c.removeReprise(r)),
                    ),
                  ),
              const Divider(thickness: 1),
              const Text('Add a repeat',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              for (final t in RepriseType.values)
                RadioListTile<RepriseType>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: t,
                  groupValue: _type,
                  title: Text(_typeName(t), style: const TextStyle(fontSize: 22)),
                  onChanged: (v) => setState(() => _type = v!),
                ),
              const SizedBox(height: 6),
              if (_type == RepriseType.voltas) ...[
                _numberField(_voltas[0]),
                _rangeRow('Volta 1', _voltas[1], _voltas[2]),
                _rangeRow('Volta 2', _voltas[3], _voltas[4]),
              ] else
                for (final f in _fields) _numberField(f),
              const SizedBox(height: 6),
              const Text(
                'Measure numbers as shown on the grid. The repeated '
                    'measures are added only while playing (Scroll Lock on), '
                    'with red numbers.',
                style: TextStyle(fontSize: 22, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
      actions: [
        const Divider(thickness: 1.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
              ),
            ),
            if (!locked)
              TextButton(
                onPressed: _add,
                child: const Text(
                  'Add',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ),
          ],
        ),
      ],
    );
  }
}