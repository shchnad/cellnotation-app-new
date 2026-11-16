import 'package:flutter/material.dart';

import '../models/composition.dart';
import '../services/composition_service.dart';
import '../controllers/composition_controller.dart';
import '../enums/music_style.dart';
import '../enums/instrument.dart';
import '../dialogs/note_values_dialog.dart';
import '../dialogs/edit_composition_dialog.dart';
import 'composition_screen.dart';

/// This screen's accent color — green, same as before, so My
/// Compositions stays visually distinct from the blue Cloud Library.
const Color _accent = Colors.blue;

class CompositionsListScreen extends StatefulWidget {
  const CompositionsListScreen({super.key});

  @override
  State<CompositionsListScreen> createState() => _CompositionsListScreenState();
}

class _CompositionsListScreenState extends State<CompositionsListScreen> {
  final CompositionService _service = CompositionService();
  final TextEditingController _searchController = TextEditingController();

  MusicStyle _styleFilter = MusicStyle.any;
  Instrument _instrumentFilter = Instrument.any;
  String _searchQuery = '';
  /// Level-of-complexity filter: 0 = any level, else 1, 2 or 3.
  int _levelFilter = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// A compact, rounded, tappable filter "pill" — an icon plus the
  /// filter's current value, highlighted in the accent color once a
  /// value other than "any" is chosen, so active filters stand out at
  /// a glance. The filter's name ([label]) is shown as a tooltip
  /// rather than inline, and the value text shrinks/ellipsizes as
  /// needed, so the whole filter bar always fits on ONE row, in both
  /// portrait and landscape.
  Widget _filterPill({
    required String label,
    required String valueText,
    required bool isActive,
    required IconData icon,
    required VoidCallback onTap,
    bool showArrow = true,
  }) {
    // Framed like the fields of the New / Edit Composition dialogs:
    // the filter's name on the frame, its value in blue bold.
    return Tooltip(
      message: label,
      child: TextField(
        readOnly: true,
        controller: TextEditingController(text: valueText),
        style: TextStyle(
          fontSize: 22,
          color: isActive ? Colors.blue : Colors.black,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          labelText: label.startsWith('Level') ? 'Level' : label,
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon, size: 22),
          suffixIcon: showArrow
              ? const Icon(Icons.arrow_drop_down, color: Colors.blue)
              : null,
        ),
        onTap: () {
          FocusScope.of(context).unfocus();
          onTap();
        },
      ),
    );
  }

  /// Search field plus filter pills, always laid out in ONE row (per
  /// request) — a Row of Expanded children rather than a Wrap, so on
  /// a narrow portrait screen everything just gets narrower instead
  /// of spilling onto a second line.
  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 22, color: Colors.blue, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: 'Search title or composer',
                hintMaxLines: 1,
                hintStyle: const TextStyle(fontSize: 22, color: Colors.black45),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.black54),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
                // Framed like the fields of the dialogs.
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.trim());
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: _filterPill(
              label: 'Style',
              valueText: _styleFilter.label,
              isActive: _styleFilter != MusicStyle.any,
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
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: _filterPill(
              label: 'Instrument',
              valueText: _instrumentFilter.label,
              isActive: _instrumentFilter != Instrument.any,
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
          ),
          const SizedBox(width: 10),
          // Level filter: each tap moves Any -> 1 -> 2 -> 3 -> Any.
          Expanded(
            flex: 1,
            child: _filterPill(
              label: 'Level of complexity (tap to change)',
              valueText: _levelFilter == 0 ? 'Any' : '$_levelFilter',
              isActive: _levelFilter != 0,
              icon: Icons.signal_cellular_alt,
              showArrow: false,
              onTap: () => setState(() => _levelFilter = (_levelFilter + 1) % 4),
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the Edit Composition dialog (the same as the pen) — also
  /// from the style, instrument and level chips of a card.
  void _openEdit(Composition comp) {
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
  }

  /// One composition as a rounded card: title and composer on top,
  /// then small info chips (style, instrument, measure count, last
  /// edited date) instead of a cramped row of table columns, with the
  /// Edit button on the right.
  Widget _compositionCard(Composition comp) {
    final measureCount = comp.timeline.measures.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        // Grey like the dialogs' buttons.
        color: Colors.grey.shade300,
        elevation: 2,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CompositionScreen(
                  // A COPY of the composition: the screen changes it while you
                  // edit, and leaving with "No" (don't save) must leave the
                  // composition in this list (and the next opening) as it
                  // was saved.
                  controller: CompositionController(
                    composition: Composition.fromJson(comp.toJson(), id: comp.id),
                  ),
                ),
              ),
            );
          },
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Title and composer take the whole width
                            // left of the pen column.
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      comp.title.isEmpty
                                          ? 'UNTITLED'
                                          : comp.title.toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      // Composer on the same line as the title.
                                      '  ·  ${comp.composer.isEmpty ? 'UNKNOWN COMPOSER' : comp.composer.toUpperCase()}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: _accent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _InfoChip(icon: Icons.palette, text: comp.style, onTap: () => _openEdit(comp)),
                            _InfoChip(icon: Icons.piano, text: comp.instrument, onTap: () => _openEdit(comp)),
                            _InfoChip(
                              icon: Icons.signal_cellular_alt,
                              text: 'Level ${comp.complexity}',
                              onTap: () => _openEdit(comp),
                            ),
                            _InfoChip(
                              plain: true,
                              icon: Icons.view_week,
                              text: '$measureCount '
                                  'm${measureCount == 1 ? '' : 's'}',
                            ),
                            _InfoChip(
                              plain: true,
                              icon: Icons.edit_calendar,
                              text: comp.editedAt
                                  .toLocal()
                                  .toString()
                                  .split(' ')
                                  .first,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // EDIT — a round button (the same size as the back
                // button) with a black pen, white like the style /
                // instrument / level chips. It has its own column at the
                // right end of the card, so on every card it sits in the
                // same place, level with the title, however long or short
                // the title and composer are.
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Tooltip(
                      message: 'Edit info',
                      child: Material(
                        color: Colors.white,
                        shape: CircleBorder(
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                        elevation: 2,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _openEdit(comp),
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(Icons.edit,
                                color: Colors.black, size: 32),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _centerMessage(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.black38),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, color: Colors.black),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // White, like the app's dialogs.
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        toolbarHeight: 80,
        leadingWidth: 88,
        // Back: a round grey button with an arrow — the same size and
        // shape as the ✕ (Exit) button of the Home screen.
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: Material(
              color: Colors.grey.shade300,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.pop(context),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.arrow_back, color: Colors.black, size: 32),
                ),
              ),
            ),
          ),
        ),
        title: const Text(
          'My Compositions',
          style: TextStyle(
            fontSize: 22,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Plain white background, like the dialogs.
          Positioned.fill(child: Container(color: Colors.white)),
          Column(
            children: [
              _buildSearchAndFilters(),
              Expanded(
                child: StreamBuilder<List<Composition>>(
                  stream: _service.getUserCompositions(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: _accent),
                      );
                    }
                    if (snapshot.hasError) {
                      return _centerMessage(
                        'Error loading compositions: ${snapshot.error}',
                        Icons.error_outline,
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
                    if (_levelFilter != 0) {
                      compositions = compositions
                          .where((c) => c.complexity == _levelFilter)
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
                      return _centerMessage(
                        'No compositions found',
                        Icons.library_music_outlined,
                      );
                    }

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${compositions.length} '
                                  'composition${compositions.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                fontSize: 22,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: compositions.length,
                            itemBuilder: (context, index) =>
                                _compositionCard(compositions[index]),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A small info item on a composition card. A chip (white, framed)
/// when it can be tapped ([onTap]: opens the Edit Composition dialog);
/// otherwise ([plain]) just an icon and text, so it doesn't look like a
/// button.
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  final bool plain;

  const _InfoChip({
    required this.icon,
    required this.text,
    this.onTap,
    this.plain = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 22, color: Colors.black87),
        ),
      ],
    );
    if (plain) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        child: content,
      );
    }
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade400),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: content,
        ),
      ),
    );
  }
}