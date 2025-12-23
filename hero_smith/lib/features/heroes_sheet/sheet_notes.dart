import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/app_database.dart';
import '../../core/repositories/hero_notes_repository.dart' as notes_repo;
import '../../core/theme/text/heroes_sheet/sheet_notes_text.dart';

// Provider for the notes repository
final heroNotesRepositoryProvider = Provider<notes_repo.HeroNotesRepository>((ref) {
  return notes_repo.HeroNotesRepository(AppDatabase.instance);
});

/// Notes page for hero sheet - mobile-friendly list view with page navigation
class SheetNotes extends ConsumerStatefulWidget {
  const SheetNotes({
    super.key,
    required this.heroId,
  });

  final String heroId;

  @override
  ConsumerState<SheetNotes> createState() => _SheetNotesState();
}

class _SheetNotesState extends ConsumerState<SheetNotes> {
  String? _currentFolderId; // null = root level
  notes_repo.NoteSortOrder _sortOrder = notes_repo.NoteSortOrder.newestFirst;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createNewNote() async {
    final noteId = await ref.read(heroNotesRepositoryProvider).createNote(
      heroId: widget.heroId,
      title: SheetNotesText.untitledNote,
      content: '',
      folderId: _currentFolderId,
    );

    if (!mounted) return;

    // Navigate to note editor
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _NoteEditorPage(
          heroId: widget.heroId,
          noteId: noteId,
          isNewNote: true,
        ),
      ),
    );

    setState(() {}); // Refresh list
  }

  Future<void> _createNewFolder() async {
    final name = await _showTextInputDialog(
      context: context,
      title: SheetNotesText.createFolderDialogTitle,
      hint: SheetNotesText.createFolderDialogHint,
      initialValue: SheetNotesText.createFolderInitialValue,
    );

    if (name == null || name.trim().isEmpty) return;

    await ref.read(heroNotesRepositoryProvider).createFolder(
      heroId: widget.heroId,
      title: name.trim(),
      parentFolderId: null, // Flat structure - folders only at root
    );

    setState(() {});
  }

  Future<void> _deleteNote(String noteId) async {
    final confirmed = await _showConfirmDialog(
      context: context,
      title: SheetNotesText.deleteNoteDialogTitle,
      message: SheetNotesText.deleteNoteDialogMessage,
    );

    if (!confirmed) return;

    await ref.read(heroNotesRepositoryProvider).deleteNote(noteId);
    setState(() {});
  }

  Future<void> _deleteFolder(String folderId) async {
    final confirmed = await _showConfirmDialog(
      context: context,
      title: SheetNotesText.deleteFolderDialogTitle,
      message: SheetNotesText.deleteFolderDialogMessage,
    );

    if (!confirmed) return;

    await ref.read(heroNotesRepositoryProvider).deleteFolder(folderId);
    
    if (_currentFolderId == folderId) {
      setState(() {
        _currentFolderId = null;
      });
    } else {
      setState(() {});
    }
  }

  Future<void> _openNote(notes_repo.HeroNote note) async {
    if (note.isFolder) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _NoteEditorPage(
          heroId: widget.heroId,
          noteId: note.id,
          isNewNote: false,
        ),
      ),
    );

    setState(() {}); // Refresh list in case note was modified
  }

  void _openFolder(String folderId) {
    setState(() {
      _currentFolderId = folderId;
    });
  }

  void _navigateBack() {
    setState(() {
      _currentFolderId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: SheetNotesText.searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _isSearching = false;
                          });
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _isSearching = value.trim().isNotEmpty;
                });
              },
            ),
          ),
          // Sort options (hide when searching)
          if (!_isSearching && _currentFolderId == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<notes_repo.NoteSortOrder>(
                      value: _sortOrder,
                      decoration: const InputDecoration(
                        labelText: SheetNotesText.sortByLabel,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: notes_repo.NoteSortOrder.newestFirst,
                          child: Text(SheetNotesText.sortNewestFirst),
                        ),
                        DropdownMenuItem(
                          value: notes_repo.NoteSortOrder.oldestFirst,
                          child: Text(SheetNotesText.sortOldestFirst),
                        ),
                        DropdownMenuItem(
                          value: notes_repo.NoteSortOrder.alphabetical,
                          child: Text(SheetNotesText.sortAlphabetical),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _sortOrder = value;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          // Notes and folders list
          Expanded(
            child: _isSearching ? _buildSearchResults() : _buildNotesList(),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_currentFolderId == null) // Only show folder button at root
            FloatingActionButton(
              heroTag: 'createFolder',
              onPressed: _createNewFolder,
              tooltip: SheetNotesText.fabCreateFolderTooltip,
              child: const Icon(Icons.create_new_folder),
            ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'createNote',
            onPressed: _createNewNote,
            tooltip: SheetNotesText.fabCreateNoteTooltip,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final repo = ref.read(heroNotesRepositoryProvider);
    return FutureBuilder<List<notes_repo.HeroNote>>(
      future: repo.searchNotes(widget.heroId, _searchController.text),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final notes = snapshot.data!;
        if (notes.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(SheetNotesText.searchNoMatches),
            ),
          );
        }

        return ListView.builder(
          itemCount: notes.length,
          itemBuilder: (context, index) {
            final note = notes[index];
            return _buildNoteCard(note);
          },
        );
      },
    );
  }

  Widget _buildNotesList() {
    final repo = ref.read(heroNotesRepositoryProvider);

    if (_currentFolderId != null) {
      // Show notes in folder with back button
      return Column(
        children: [
          ListTile(
            leading: const Icon(Icons.arrow_back),
            title: const Text(SheetNotesText.backToNotes),
            tileColor: Theme.of(context).colorScheme.surfaceVariant,
            onTap: _navigateBack,
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<notes_repo.HeroNote>>(
              future: repo.getNotesInFolder(_currentFolderId!, sortOrder: _sortOrder),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final notes = snapshot.data!;
                if (notes.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(SheetNotesText.folderEmpty),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return _buildNoteCard(note);
                  },
                );
              },
            ),
          ),
        ],
      );
    }

    // Show root level items (folders and notes without folder)
    return FutureBuilder<List<notes_repo.HeroNote>>(
      future: repo.getRootItems(widget.heroId, sortOrder: _sortOrder),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data!;
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                SheetNotesText.rootEmpty,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ),
          );
        }

        // Separate folders and notes
        final folders = items.where((item) => item.isFolder).toList();
        final notes = items.where((item) => !item.isFolder).toList();

        return ListView(
          children: [
            if (folders.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  SheetNotesText.sectionFolders,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              ...folders.map((folder) => _buildFolderCard(folder)),
              if (notes.isNotEmpty) const SizedBox(height: 16),
            ],
            if (notes.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  SheetNotesText.sectionNotes,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              ...notes.map((note) => _buildNoteCard(note)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildFolderCard(notes_repo.HeroNote folder) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.folder, size: 32),
        title: Text(
          folder.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          SheetNotesText.created(_formatDate(folder.createdAt)),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _deleteFolder(folder.id),
          tooltip: SheetNotesText.tooltipDeleteFolder,
        ),
        onTap: () => _openFolder(folder.id),
      ),
    );
  }

  Widget _buildNoteCard(notes_repo.HeroNote note) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.note, size: 28),
        title: Text(
          note.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (note.content.isNotEmpty)
              Text(
                note.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            const SizedBox(height: 4),
            Text(
              SheetNotesText.updated(_formatDate(note.updatedAt)),
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _deleteNote(note.id),
          tooltip: SheetNotesText.tooltipDeleteNote,
        ),
        onTap: () => _openNote(note),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) return SheetNotesText.dateJustNow;
        return SheetNotesText.dateMinutesAgo(diff.inMinutes);
      }
      return SheetNotesText.dateHoursAgo(diff.inHours);
    } else if (diff.inDays == 1) {
      return SheetNotesText.dateYesterday;
    } else if (diff.inDays < 7) {
      return SheetNotesText.dateDaysAgo(diff.inDays);
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

/// Separate page for editing a note
class _NoteEditorPage extends ConsumerStatefulWidget {
  const _NoteEditorPage({
    required this.heroId,
    required this.noteId,
    required this.isNewNote,
  });

  final String heroId;
  final String noteId;
  final bool isNewNote;

  @override
  ConsumerState<_NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends ConsumerState<_NoteEditorPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  bool _isLoading = true;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _loadNote();
    _titleController.addListener(_onChanged);
    _contentController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!_isDirty) {
      setState(() {
        _isDirty = true;
      });
    }
  }

  Future<void> _loadNote() async {
    final repo = ref.read(heroNotesRepositoryProvider);
    final note = await repo.getNote(widget.noteId);

    if (note == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    setState(() {
      _titleController.text = note.title;
      _contentController.text = note.content;
      _isLoading = false;
      _isDirty = false;
    });
  }

  Future<void> _saveNote() async {
    final repo = ref.read(heroNotesRepositoryProvider);
    await repo.updateNote(
      noteId: widget.noteId,
      title: _titleController.text.trim().isEmpty
          ? SheetNotesText.untitledNote
          : _titleController.text.trim(),
      content: _contentController.text,
    );

    setState(() {
      _isDirty = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(SheetNotesText.noteSavedSnack),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<bool> _onWillPop() async {
    if (_isDirty) {
      await _saveNote();
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(SheetNotesText.editNoteTitle),
          actions: [
            if (_isDirty)
              IconButton(
                icon: const Icon(Icons.save),
                tooltip: SheetNotesText.saveTooltip,
                onPressed: _saveNote,
              ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Title field
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: SheetNotesText.fieldTitleLabel,
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Content field
              Expanded(
                child: TextField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    labelText: SheetNotesText.fieldContentLabel,
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper dialog functions
Future<String?> _showTextInputDialog({
  required BuildContext context,
  required String title,
  required String hint,
  String? initialValue,
}) async {
  final controller = TextEditingController(text: initialValue);
  return showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(SheetNotesText.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text(SheetNotesText.actionCreate),
          ),
        ],
      );
    },
  );
}

Future<bool> _showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(SheetNotesText.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(SheetNotesText.actionDelete),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
