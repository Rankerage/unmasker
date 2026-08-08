import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../widgets/note_card.dart';
import 'editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _isSearching = false;
  String _activeFolder = '전체';

  @override
  Widget build(BuildContext context) {
    final service = context.watch<NoteService>();
    final dark = service.globalDarkMode;
    final results = _query.isNotEmpty ? service.search(_query) : null;
    final allPinned = results ?? service.pinnedNotes;
    final allUnpinned = results != null ? <UnmaskerNote>[] : service.unpinnedNotes;
    final pinned = _activeFolder == '전체' ? allPinned : allPinned.where((n) => n.folder == _activeFolder).toList();
    final unpinned = _activeFolder == '전체' ? allUnpinned : allUnpinned.where((n) => n.folder == _activeFolder).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchCtrl, autofocus: true,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(hintText: '노트 검색', border: InputBorder.none, isDense: true),
                onChanged: (v) => setState(() => _query = v)),
              )
            : const Text('Unmasker', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: Colors.black)),
        actions: [
          IconButton(icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.black87, size: 22),
            onPressed: () => setState(() { _isSearching = !_isSearching; _query = ''; _searchCtrl.clear(); })),
          IconButton(icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: Colors.black87, size: 22),
            onPressed: () => service.toggleDarkMode()),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black87, size: 22),
            position: PopupMenuPosition.under,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (v) {
              if (v == 'folder') _showFolderDialog(service);
              if (v == 'updated') service.setSort(NoteSort.updated);
              if (v == 'created') service.setSort(NoteSort.created);
              if (v == 'title') service.setSort(NoteSort.title);
              if (v == 'grid2') service.setGridColumns(2);
              if (v == 'grid1') service.setGridColumns(1);
              if (v == 'grid3') service.setGridColumns(3);
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'folder', height: 40, child: Text('폴더 관리', style: TextStyle(fontSize: 14))),
              const PopupMenuDivider(height: 1),
              const PopupMenuItem(value: 'sort_header', enabled: false, height: 30, child: Text('정렬', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600))),
              _popItem('updated', '최근 수정순'), _popItem('created', '생성순'), _popItem('title', '제목순'),
              const PopupMenuDivider(height: 1),
              const PopupMenuItem(value: 'view_header', enabled: false, height: 30, child: Text('보기', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600))),
              _popItem('grid2', '2열 그리드'), _popItem('grid1', '리스트'), _popItem('grid3', '3열 그리드'),
            ],
          ),
        ],
      ),
      body: Column(children: [
        // 폴더 칩
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              const SizedBox(width: 8),
              _chip('전체', service.notes.length, _activeFolder == '전체'),
              for (final folder in service.folders)
                _chip(folder, service.notesInFolder(folder).length, _activeFolder == folder),
              const SizedBox(width: 8),
            ]),
          ),
        ),
        const SizedBox(height: 4),
        // 노트 그리드
        Expanded(
          child: pinned.isEmpty && unpinned.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.auto_stories, size: 56, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(_query.isNotEmpty ? '검색 결과 없음' : '새 노트를 만들어보세요',
                    style: TextStyle(color: Colors.grey[400], fontSize: 15)),
                ]),
              )
              : service.gridColumns == 1
                  ? ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: pinned.length + unpinned.length,
                      itemBuilder: (ctx, i) {
                        final note = i < pinned.length ? pinned[i] : unpinned[i - pinned.length];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: NoteCard(note: note, isPinned: i < pinned.length,
                            onTap: () => _openNote(note),
                            onTogglePin: () => service.updateNote(note.id, isPinned: !note.isPinned),
                            onDelete: () => service.deleteNote(note.id),
                          ),
                        );
                      })
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: service.gridColumns,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 10, mainAxisSpacing: 10,
                      ),
                      itemCount: pinned.length + unpinned.length,
                      itemBuilder: (ctx, i) {
                        final note = i < pinned.length ? pinned[i] : unpinned[i - pinned.length];
                        return NoteCard(note: note, isPinned: i < pinned.length,
                          onTap: () => _openNote(note),
                          onTogglePin: () => service.updateNote(note.id, isPinned: !note.isPinned),
                          onDelete: () => service.deleteNote(note.id),
                        );
                      },
                    ),
        ),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openNote(UnmaskerNote()),
        backgroundColor: const Color(0xFFFFD54F),
        foregroundColor: Colors.black87,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.edit, size: 24),
      ),
    );
  }

  Widget _chip(String name, int count, bool selected) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text('$name ($count)', style: TextStyle(fontSize: 12, color: selected ? Colors.black87 : Colors.black54)),
        selected: selected,
        selectedColor: const Color(0xFFFFF176),
        backgroundColor: Colors.grey[100],
        checkmarkColor: Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
        onSelected: (_) => setState(() => _activeFolder = name),
      ),
    );
  }

  PopupMenuItem<String> _popItem(String value, String text) {
    return PopupMenuItem(value: value, height: 36, child: Text(text, style: const TextStyle(fontSize: 14)));
  }

  void _openNote(UnmaskerNote note) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => EditorScreen(note: note)));
  }

  void _showFolderDialog(NoteService service) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('폴더 관리', style: TextStyle(fontSize: 17)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final f in service.folders)
          ListTile(
            dense: true,
            title: Text(f, style: const TextStyle(fontSize: 14)),
            trailing: f != '기본' ? IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), onPressed: () { service.deleteFolder(f); Navigator.pop(ctx); }) : null),
      ]),
      actions: [
        TextButton(onPressed: () async {
          final ctrl = TextEditingController();
          final name = await showDialog<String>(context: ctx, builder: (_) => AlertDialog(
            title: const Text('새 폴더'), content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: '폴더 이름')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(_), child: const Text('취소')),
              TextButton(onPressed: () => Navigator.pop(_, ctrl.text), child: const Text('추가')),
            ],
          ));
          if (name != null && name.isNotEmpty) { service.addFolder(name); Navigator.pop(ctx); }
        }, child: const Text('폴더 추가')),
      ],
    ));
  }
}
