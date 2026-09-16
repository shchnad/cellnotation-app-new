import 'package:flutter/material.dart';

import '../models/composition.dart';
import '../services/composition_service.dart';
import '../controllers/composition_controller.dart';
import '../enums/music_style.dart';
import '../enums/instrument.dart';
import '../dialogs/note_values_dialog.dart';
import '../dialogs/edit_composition_dialog.dart';
import 'composition_screen.dart';

/// Capitalizes just the first letter for display — the underlying
/// data (comp.title/comp.composer) is left exactly as stored;
/// this only affects how it's shown here.
String _capitalizeFirst(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class CompositionsListScreen extends StatefulWidget {
  const CompositionsListScreen({super.key});

  @override
  State<CompositionsListScreen> createState() => _CompositionsListScreenState();
}

class _CompositionsListScreenState extends State<CompositionsListScreen> {
  final CompositionService _service = CompositionService();
  final TextEditingController _searchController = TextEditingController();

  // MusicStyle.any / Instrument.any act as the "no filter" state,
  // consistent with how "any" is used elsewhere in the app.
  MusicStyle _styleFilter = MusicStyle.any;
  Instrument _instrumentFilter = Instrument.any;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildFilterField({
    required String label,
    required String valueText,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: TextFormField(
        readOnly: true,
        controller: TextEditingController(text: valueText),
        style: const TextStyle(
          fontSize: 22,
          color: Colors.green,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            fontSize: 22,
            color: Colors.black,
          ),
          isDense: true,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon, size: 20),
          suffixIcon: const Icon(
            Icons.arrow_drop_down,
            color: Colors.blue,
          ),
        ),
        onTap: () {
          FocusScope.of(context).unfocus();
          onTap();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Explicit leading icon (blue) — the default automatic back
        // arrow AppBar provides otherwise uses the theme's own
        // default color, not blue. Matches the same treatment
        // applied to CloudLibraryScreen (green there instead).
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.green),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('My Compositions', style: TextStyle(
          fontSize: 22,
          color: Colors.green,
          fontWeight: FontWeight.bold,
        )),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      labelText:
                      'Search title or composer',
                      labelStyle: TextStyle(
                        fontSize: 22,
                        color: Colors.black,
                      ),
                      isDense: true,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value.trim());
                    },
                  ),
                ),
                const SizedBox(width: 12),
                _buildFilterField(
                  label: 'Style',
                  valueText: _styleFilter.label,
                  icon: Icons.palette,
                  onTap: () {
                    noteValuesDialog<MusicStyle>(
                      allowToCloseNextWindow: false,
                      context: context,
                      title: 'Filter by Style',
                      currentValue: _styleFilter,
                      values: MusicStyle.values,
                      labelBuilder: (s) => s.label,
                      numberOfColumns: 3,
                      onSelected: (style) =>
                          setState(() => _styleFilter = style),
                    );
                  },
                ),
                const SizedBox(width: 12),
                _buildFilterField(
                  label: 'Instrument',
                  valueText: _instrumentFilter.label,
                  icon: Icons.piano,
                  onTap: () {
                    noteValuesDialog<Instrument>(
                      context: context,
                      allowToCloseNextWindow: false,
                      title: 'Filter by Instrument',
                      currentValue: _instrumentFilter,
                      values: Instrument.values,
                      labelBuilder: (i) => i.label,
                      numberOfColumns: 3,
                      onSelected: (inst) =>
                          setState(() => _instrumentFilter = inst),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Container(
            // horizontal padding matches the DATA ROW Container's
            // own (16, not the previous 8) — per request, every
            // column header must align with its data column below,
            // the same fix applied to CloudLibraryScreen: Row lays
            // out Expanded columns by dividing whatever width is
            // left after this Container's own padding, so a
            // mismatched padding here shifted every column's
            // flex-based width slightly versus the data row below.
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade300,
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  // Matches the data row's own left indent on Title
                  // exactly (see below) — now that this Container's
                  // padding matches the data row's, both need the
                  // SAME extra indent to land at the same pixel.
                  child: const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Text('Title', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22)),
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text('Composer', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22)),
                ),
                const Expanded(
                  flex: 2,
                  child: Text('Style', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22)),
                ),
                const Expanded(
                  flex: 2,
                  child: Text('Instrument', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22)),
                ),
                const Expanded(
                  flex: 2,
                  child: Text('Edited', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22)),
                ),
                // Matches the data row's own trailing SizedBox width
                // (48, an IconButton's real Material default tap-
                // target size — not the earlier guessed 44, which
                // didn't actually match how wide an IconButton
                // renders) — same fix as CloudLibraryScreen's.
                const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Composition>>(
              stream: _service.getUserCompositions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading compositions: ${snapshot.error}',
                      style: const TextStyle(fontSize: 22),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                var compositions = snapshot.data ?? [];

                if (_styleFilter != MusicStyle.any) {
                  compositions = compositions
                      .where((c) => c.style == _styleFilter.label)
                      .toList();
                }
                if (_instrumentFilter != Instrument.any) {
                  compositions = compositions
                      .where((c) => c.instrument == _instrumentFilter.label)
                      .toList();
                }
                if (_searchQuery.isNotEmpty) {
                  final query = _searchQuery.toLowerCase();
                  compositions = compositions
                      .where((c) =>
                  c.title.toLowerCase().contains(query) ||
                      c.composer.toLowerCase().contains(query))
                      .toList();
                }

                if (compositions.isEmpty) {
                  return const Center(
                    child: Text(
                      'No compositions found',
                      style: TextStyle(fontSize: 22),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: compositions.length,
                  itemBuilder: (context, index) {
                    final comp = compositions[index];
                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CompositionScreen(
                              controller: CompositionController(composition: comp),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Padding(
                                // Matches the header's own 12px
                                // indent on Title exactly, per
                                // request — same treatment as
                                // CloudLibraryScreen's.
                                padding: const EdgeInsets.only(left: 12),
                                child: Text(
                                  _capitalizeFirst(comp.title),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                _capitalizeFirst(comp.composer),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                comp.style,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 22, color: Colors.black),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                comp.instrument,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 22, color: Colors.black),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                comp.editedAt.toLocal().toString().split(' ').first,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 22, color: Colors.black),
                              ),
                            ),
                            SizedBox(
                              width: 48,
                              child: IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                tooltip: 'Edit info',
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => EditCompositionDialog(
                                      composition: comp,
                                      onSaved: (updated) async {
                                        await _service.saveComposition(updated);
                                      },
                                      onDelete: () async {
                                        if (comp.id != null) {
                                          await _service.deleteComposition(comp.id!);
                                        }
                                      },
                                      allowDelete: true,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}