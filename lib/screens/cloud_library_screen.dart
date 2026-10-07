import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/composition.dart';
import '../services/composition_service.dart';
import '../controllers/composition_controller.dart';
import '../enums/music_style.dart';
import '../enums/instrument.dart';
import '../dialogs/note_values_dialog.dart';
import 'composition_screen.dart';

/// This screen's accent color — blue, same as before, so the Cloud
/// Library stays visually distinct from the green My Compositions.
const Color _accent = Colors.blue;

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

  Future<void> _copyToMyLibrary(BuildContext context, Composition comp) async {
    try {
      await _service.copyToMyLibrary(comp);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 2),
          content: Text('Copied to My Compositions', style: TextStyle(fontSize: 20)),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text('Copy failed: $e', style: const TextStyle(fontSize: 20)),
        ),
      );
    }
  }

  Future<void> _toggleLike(BuildContext context, Composition comp) async {
    if (comp.id == null) return;
    try {
      await _service.toggleLike(comp.id!, comp.isLikedBy(_myUid));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text('Failed: $e', style: const TextStyle(fontSize: 18)),
        ),
      );
    }
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
    return Tooltip(
      message: label,
      child: Material(
        color: isActive ? _accent : Colors.white,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () {
            FocusScope.of(context).unfocus();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 22, color: isActive ? Colors.white : _accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    valueText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                if (showArrow)
                  Icon(
                    Icons.arrow_drop_down,
                    color: isActive ? Colors.white : Colors.black54,
                  ),
              ],
            ),
          ),
        ),
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
              style: const TextStyle(fontSize: 20, color: Colors.black),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: 'Search title or composer',
                hintMaxLines: 1,
                hintStyle: const TextStyle(fontSize: 20, color: Colors.black45),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                prefixIcon: const Icon(Icons.search, color: _accent),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
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
          // Sort toggle — kept from before: a pill showing the current
          // order (heart = most liked, clock = most recent).
          Expanded(
            flex: 2,
            child: _filterPill(
              label: 'Sort',
              valueText: _sortByLikes ? 'Most liked' : 'Most recent',
              isActive: _sortByLikes,
              icon: _sortByLikes ? Icons.favorite : Icons.schedule,
              showArrow: false,
              onTap: () => setState(() => _sortByLikes = !_sortByLikes),
            ),
          ),
        ],
      ),
    );
  }

  /// One shared composition as a rounded card: title, composer and
  /// who shared it on top, then info chips (style, instrument,
  /// measure count), with the Like and Copy actions on the right.
  Widget _compositionCard(BuildContext context, Composition comp) {
    final isMine = comp.userId == _myUid;
    final liked = comp.isLikedBy(_myUid);
    final measureCount = comp.timeline.measures.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.white,
        elevation: 3,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            // Opens the shared composition in the editor. Since it's
            // not "yours", saving there will still write to the
            // original doc if you own it, or fail via security rules
            // if not — "Copy" is the safe way to make it truly yours.
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CompositionScreen(
                  controller: CompositionController(composition: comp),
                ),
              ),
            );
          },
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Accent stripe down the card's left edge.
                Container(width: 6, color: _accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                comp.title.isEmpty
                                    ? 'UNTITLED'
                                    : comp.title.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            if (isMine) ...[
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _accent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'yours',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          comp.composer.isEmpty
                              ? 'UNKNOWN COMPOSER'
                              : comp.composer.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          // Composer: accent color, regular (not italic), bold.
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _accent,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _InfoChip(icon: Icons.person, text: comp.userName),
                            _InfoChip(icon: Icons.palette, text: comp.style),
                            _InfoChip(icon: Icons.piano, text: comp.instrument),
                            _InfoChip(
                              icon: Icons.view_week,
                              text: '$measureCount '
                                  'measure${measureCount == 1 ? '' : 's'}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Like button with its count underneath.
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        liked ? Icons.favorite : Icons.favorite_border,
                        color: liked ? Colors.red : Colors.grey,
                      ),
                      iconSize: 28,
                      tooltip: liked ? 'Unlike' : 'Like',
                      onPressed: () => _toggleLike(context, comp),
                    ),
                    Text(
                      '${comp.likeCount}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                Center(
                  child: IconButton(
                    icon: const Icon(Icons.download, color: _accent),
                    iconSize: 28,
                    tooltip: 'Copy to My Compositions',
                    onPressed: () => _copyToMyLibrary(context, comp),
                  ),
                ),
                const SizedBox(width: 8),
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
          Icon(icon, size: 56, color: Colors.white70),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, color: Colors.white),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _accent),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Cloud Library',
          style: TextStyle(
            fontSize: 22,
            color: _accent,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/cellnotation_background.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.45)),
          ),
          Column(
            children: [
              _buildSearchAndFilters(),
              Expanded(
                child: StreamBuilder<List<Composition>>(
                  stream: _service.getPublicCompositions(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: _accent),
                      );
                    }
                    if (snapshot.hasError) {
                      return _centerMessage(
                        'Error loading library: ${snapshot.error}',
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
                      return _centerMessage(
                        'No public compositions found',
                        Icons.cloud_off,
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
                                fontSize: 18,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: compositions.length,
                            itemBuilder: (context, index) =>
                                _compositionCard(context, compositions[index]),
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

/// A small rounded info chip (icon + text) used on each composition
/// card for shared-by, style, instrument and measure count.
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.blue.shade700),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontSize: 18, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}