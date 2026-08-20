import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/composition.dart';
import '../services/composition_service.dart';
import '../controllers/composition_controller.dart';
import '../enums/music_style.dart';
import '../enums/instrument.dart';
import '../dialogs/note_values_dialog.dart';
import 'composition_screen.dart';

/// Capitalizes just the first letter for display — the underlying
/// data (comp.title/comp.composer) is left exactly as stored; this
/// only affects how it's shown here. Matches
/// CompositionsListScreen's own identical helper.
String _capitalizeFirst(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

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
  bool _sortByLikes = false;

  String? get _myUid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Matches CompositionsListScreen's own _buildFilterField exactly —
  // fontSize 22 blue bold value, black 22px label.
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
          color: Colors.blue,
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
        // Same size/weight as CompositionsListScreen's "My
        // Compositions" title — only difference (per request) is the
        // color: black here instead of blue.
        title: const Text('Cloud Library', style: TextStyle(
          fontSize: 22,
          color: Colors.black,
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
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Search title or composer',
                      labelStyle: const TextStyle(
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
                      allowToCloseNextWindow: false,
                      title: 'Filter by Instrument',
                      currentValue: _instrumentFilter,
                      values: Instrument.values,
                      labelBuilder: (i) => i.label,
                      numberOfColumns: 3,
                      onSelected: (inst) => setState(() => _instrumentFilter = inst),
                    );
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    _sortByLikes ? Icons.favorite : Icons.access_time,
                    color: _sortByLikes ? Colors.red : Colors.black,
                  ),
                  tooltip: _sortByLikes
                      ? 'Sorted by most liked (tap for most recent)'
                      : 'Sorted by most recent (tap for most liked)',
                  onPressed: () {
                    setState(() => _sortByLikes = !_sortByLikes);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Header — same grey.shade300 background + black bold
          // fontSize 22 text as CompositionsListScreen's header, and
          // Title given the same proportionally larger flex (5)
          // widening it the same way. "Shared by" and "Likes" are
          // extra columns CompositionsListScreen doesn't have, kept
          // here since this screen genuinely needs them.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: Colors.grey.shade300,
            child: const Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text('Title', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Composer', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Shared by', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Style', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Instrument', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22)),
                ),
                SizedBox(
                  width: 110,
                  child: Text('Likes', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22)),
                ),
                SizedBox(width: 40),
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

                if (_sortByLikes) {
                  compositions = [...compositions]
                    ..sort((a, b) => b.likeCount.compareTo(a.likeCount));
                }
                // else: keep the order already provided by Firestore
                // (most recently edited first).

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
                            // Title/composer/style/instrument styled
                            // exactly like CompositionsListScreen's
                            // own data row (fontSize 22 bold title,
                            // fontSize 22 composer, fontSize 16 black
                            // for style/instrument — replacing the
                            // earlier blueGrey/grey coloring).
                            Expanded(
                              flex: 5,
                              child: Text(
                                _capitalizeFirst(comp.title),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
                                comp.userName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 16, color: Colors.black),
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
                            if (isMine)
                              const Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: Text('(yours)', style: TextStyle(fontSize: 12, color: Colors.blue)),
                              ),
                            IconButton(
                              icon: Icon(
                                comp.isLikedBy(_myUid) ? Icons.favorite : Icons.favorite_border,
                                size: 20,
                                color: comp.isLikedBy(_myUid) ? Colors.red : Colors.grey,
                              ),
                              tooltip: comp.isLikedBy(_myUid) ? 'Unlike' : 'Like',
                              onPressed: () async {
                                if (comp.id == null) return;
                                try {
                                  await _service.toggleLike(comp.id!, comp.isLikedBy(_myUid));
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed: $e', style: const TextStyle(fontSize: 18))),
                                  );
                                }
                              },
                            ),
                            SizedBox(
                              width: 24,
                              child: Text(
                                '${comp.likeCount}',
                                style: const TextStyle(fontSize: 16, color: Colors.black),
                              ),
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