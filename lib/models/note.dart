import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

enum NoteSort { updated, created, title, folder }

class UnmaskerNote {
  final String id;
  String title;
  String content;
  String folder;
  final DateTime createdAt;
  DateTime updatedAt;
  bool isPinned;
  bool hasDrawing;
  List<String> imagePaths;
  String? pdfPath;
  String? audioPath;
  List<Map<String, dynamic>> drawingStrokes;
  bool isDarkMode;

  UnmaskerNote({
    String? id,
    this.title = '',
    this.content = '',
    this.folder = '기본',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isPinned = false,
    this.hasDrawing = false,
    this.imagePaths = const [],
    this.pdfPath,
    this.audioPath,
    this.drawingStrokes = const [],
    this.isDarkMode = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id, 'title': title, 'content': content, 'folder': folder,
        'createdAt': createdAt.toIso8601String(), 'updatedAt': updatedAt.toIso8601String(),
        'isPinned': isPinned ? 1 : 0, 'hasDrawing': hasDrawing ? 1 : 0,
        'imagePaths': jsonEncode(imagePaths),
        'pdfPath': pdfPath ?? '', 'audioPath': audioPath ?? '',
        'drawingStrokes': jsonEncode(drawingStrokes),
        'isDarkMode': isDarkMode ? 1 : 0,
      };

  factory UnmaskerNote.fromMap(Map<String, dynamic> map) => UnmaskerNote(
        id: map['id'], title: map['title'] ?? '', content: map['content'] ?? '',
        folder: map['folder'] ?? '기본',
        createdAt: DateTime.parse(map['createdAt']), updatedAt: DateTime.parse(map['updatedAt']),
        isPinned: (map['isPinned'] ?? 0) == 1, hasDrawing: (map['hasDrawing'] ?? 0) == 1,
        imagePaths: map['imagePaths'] != null && map['imagePaths'].isNotEmpty
            ? List<String>.from(jsonDecode(map['imagePaths'])) : [],
        pdfPath: (map['pdfPath'] != null && map['pdfPath'].isNotEmpty) ? map['pdfPath'] : null,
        audioPath: (map['audioPath'] != null && map['audioPath'].isNotEmpty) ? map['audioPath'] : null,
        drawingStrokes: map['drawingStrokes'] != null && map['drawingStrokes'].isNotEmpty
            ? List<Map<String, dynamic>>.from(jsonDecode(map['drawingStrokes'])) : [],
        isDarkMode: (map['isDarkMode'] ?? 0) == 1,
      );
}

class NoteService extends ChangeNotifier {
  List<UnmaskerNote> _notes = [];
  Set<String> _folders = {'기본'};
  NoteSort _sortBy = NoteSort.updated;
  int _gridColumns = 2;
  bool _globalDarkMode = false;

  List<UnmaskerNote> get notes => List.unmodifiable(_notes);
  Set<String> get folders => Set.unmodifiable(_folders);
  NoteSort get sortBy => _sortBy;
  int get gridColumns => _gridColumns;
  bool get globalDarkMode => _globalDarkMode;

  List<UnmaskerNote> search(String query) {
    final q = query.toLowerCase();
    return _notes.where((n) => n.title.toLowerCase().contains(q) || n.content.toLowerCase().contains(q)).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<UnmaskerNote> get pinnedNotes => _notes.where((n) => n.isPinned).toList()..sort(_sorter);
  List<UnmaskerNote> get unpinnedNotes => _notes.where((n) => !n.isPinned).toList()..sort(_sorter);
  List<UnmaskerNote> notesInFolder(String folder) => _notes.where((n) => n.folder == folder).toList()..sort(_sorter);

  int _sorter(UnmaskerNote a, UnmaskerNote b) {
    switch (_sortBy) {
      case NoteSort.updated: return b.updatedAt.compareTo(a.updatedAt);
      case NoteSort.created: return b.createdAt.compareTo(a.createdAt);
      case NoteSort.title: return a.title.compareTo(b.title);
      case NoteSort.folder: return a.folder.compareTo(b.folder);
    }
  }

  void setSort(NoteSort sort) { _sortBy = sort; notifyListeners(); }
  void setGridColumns(int cols) { _gridColumns = cols.clamp(1, 3); notifyListeners(); }
  void toggleDarkMode() { _globalDarkMode = !_globalDarkMode; notifyListeners(); }

  void addNote(UnmaskerNote note) { _notes.insert(0, note); notifyListeners(); _saveNotes(); }
  
  void updateNote(String id, {String? title, String? content, String? folder, bool? isPinned, List<String>? imagePaths, String? pdfPath, String? audioPath, List<Map<String, dynamic>>? drawingStrokes}) {
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      if (title != null) _notes[idx].title = title;
      if (content != null) _notes[idx].content = content;
      if (folder != null) _notes[idx].folder = folder;
      if (isPinned != null) _notes[idx].isPinned = isPinned;
      if (imagePaths != null) _notes[idx].imagePaths = imagePaths;
      if (pdfPath != null) _notes[idx].pdfPath = pdfPath;
      if (audioPath != null) _notes[idx].audioPath = audioPath;
      if (drawingStrokes != null) _notes[idx].drawingStrokes = drawingStrokes;
      _notes[idx].updatedAt = DateTime.now();
      notifyListeners();
      _saveNotes();
    }
  }

  void deleteNote(String id) { _notes.removeWhere((n) => n.id == id); notifyListeners(); _saveNotes(); }
  void addFolder(String name) { _folders.add(name); notifyListeners(); }
  void deleteFolder(String name) { if (name == '기본') return; _folders.remove(name); _notes.removeWhere((n) => n.folder == name); notifyListeners(); _saveNotes(); }

  Future<void> _saveNotes() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/notes.json');
    await file.writeAsString(jsonEncode(_notes.map((n) => n.toMap()).toList()));
  }

  Future<void> loadNotes() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/notes.json');
    if (await file.exists()) {
      final data = jsonDecode(await file.readAsString()) as List;
      _notes = data.map((m) => UnmaskerNote.fromMap(m)).toList();
      _folders = _notes.map((n) => n.folder).toSet(); _folders.add('기본');
      notifyListeners();
    }
  }
}
