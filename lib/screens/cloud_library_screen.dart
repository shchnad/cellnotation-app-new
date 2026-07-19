import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/composition.dart';
import '../services/composition_service.dart';
import '../controllers/composition_controller.dart';
import '../enums/music_style.dart';
import '../enums/instrument.dart';
import '../dialogs/note_values_dialog.dart';
import 'composition_screen.dart';

class CloudLibraryScreen extends StatefulWidget {
  const CloudLibraryScreen({super.key});

  @override
  State<CloudLibraryScreen> createState() => _CloudLibraryScreenState();
}

class _CloudLibraryScreenState extends State<CloudLibraryScreen> {
  final CompositionService _service = CompositionService();
  final TextEditingController _searchController = TextEditingController();

  MusicStyle _styleFilter = MusicStyle.any;
  Instrument _instrumentFilter = Instrument.any;
  String _searchQuery = '';

  String? get _myUid => FirebaseAuth.instance.currentUser?.uid;

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
          fontSize: 18,
          color: Colors.blue,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon, size: 20),
          suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
        ),
        onTap: () {
          FocusScope.of(context).unfocus();
          onTap();
        },
      ),
    );
  }

  Future<void> _copyToMyLibrary(BuildContext context, Composition comp) async {
    try {
      await _service.copyToMyLibrary(comp);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied to My Compositions', style: TextStyle(fontSize: 20)),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Copy failed: $e', style: const TextStyle(fontSize: 20))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Library', style: TextStyle(fontSize: 22)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                      labelText: 'Search title or composer',
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
                      context: context,
                      title: 'Filter by Style',
                      currentValue: _styleFilter,
                      values: MusicStyle.values,
                      labelBuilder: (s) => s.label,
                      numberOfColumns: 3,
                      onSelected: (style) => setState(() => _styleFilter = style),
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
                      title: 'Filter by Instrument',
                      currentValue: _instrumentFilter,
                      values: Instrument.values,
                      labelBuilder: (i) => i.label,
                      numberOfColumns: 3,
                      onSelected: (inst) => setState(() => _instrumentFilter = inst),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade200,
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('Title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Composer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Style', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Instrument', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                SizedBox(width: 44),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Composition>>(
              stream: _service.getPublicCompositions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading library: ${snapshot.error}',
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
                    child: Text('No public compositions found', style: TextStyle(fontSize: 22)),
                  );
                }

                return ListView.builder(
                  itemCount: compositions.length,
                  itemBuilder: (context, index) {
                    final comp = compositions[index];
                    final isMine = comp.userId == _myUid;
                    return InkWell(
                      onTap: () {
                        // Open read-only-ish: opens the shared composition
                        // in the editor. Since it's not "yours", saving
                        // there will still write to the original doc if
                        // you own it, or fail via security rules if not —
                        // "Copy" below is the safe way to make it truly yours.
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                comp.title,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                comp.composer,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                comp.style,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                comp.instrument,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ),
                            if (isMine)
                              const Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: Text('(yours)', style: TextStyle(fontSize: 12, color: Colors.blue)),
                              ),
                            IconButton(
                              icon: const Icon(Icons.download, size: 20),
                              tooltip: 'Copy to My Compositions',
                              onPressed: () => _copyToMyLibrary(context, comp),
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