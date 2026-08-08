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
      backgroundColor: dark ? const Color(0xFF1A1A1A) : const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: dark ? const Color(0xFF2D2D2D) : Colors.white,
        elevation: 0.5,
        title: _isSearching
            ? TextField(
                controller: _searchCtrl, autofocus: true,
                style: TextStyle(color: dark ? Colors.white : Colors.black),
                decoration: InputDecoration(hintText: '노트 검색...', border: InputBorder.none, hintStyle: TextStyle(color: dark ? Colors.grey[500] : Colors.grey[400])),
                onChanged: (v) => setState(() => _query = v)),
              )
            : const Text('Unmasker', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black)),
        actions: [
          IconButton(icon: Icon(_isSearching ? Icons.close : Icons.search, color: dark ? Colors.white : Colors.black),
            onPressed: () => setState(() { _isSearching = !_isSearching; _query = ''; _searchCtrl.clear(); })),
          IconButton(icon: Icon(dark ? Icons.light_mode : Icons.dark_mode, color: dark ? Colors.white : Colors.black),
            onPressed: () => service.toggleDarkMode()),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: dark ? Colors.white : Colors.black),
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
              const PopupMenuItem(value: 'folder', child: Text('폴더 관리')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'sort_header', enabled: false, child: Text('정렬', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
              const PopupMenuItem(value: 'updated', child: Text('최근 수정순')),
              const PopupMenuItem(value: 'created', child: Text('생성순')),
              const PopupMenuItem(value: 'title', child: Text('제목순')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'view_header', enabled: false, child: Text('보기', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
              const PopupMenuItem(value: 'grid2', child: Text('2열 그리드')),
              const PopupMenuItem(value: 'grid1', child: Text('리스트')),
              const PopupMenuItem(value: 'grid3', child: Text('3열 그리드')),
            ],
          ),
        ],
      ),
      body: Column(children: [
        Container(
          color: dark ? const Color(0xFF2D2D2D) : Colors.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(children: [
              _buildChip('전체', service.notes.length, _activeFolder == '전체'),
              for (final folder in service.folders)
                _buildChip(folder, service.notesInFolder(folder).length, _activeFolder == folder),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: pinned.isEmpty && unpinned.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.note_add_outlined, size: 64, color: dark ? Colors.grey[700] : Colors.grey),
                  const SizedBox(height: 12),
                  Text(_query.isNotEmpty ? '검색 결과 없음' : '새 노트를 만들어보세요', style: TextStyle(color: dark ? Colors.grey[500] : Colors.grey, fontSize: 16)),
                ]),
              )
              : service.gridColumns == 1
                  ? ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: service.gridColumns,
                        childAspectRatio: service.gridColumns == 2 ? 0.85 : 0.7,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNote(UnmaskerNote()),
        backgroundColor: const Color(0xFFFFD54F), foregroundColor: Colors.black,
        icon: const Icon(Icons.edit), label: const Text('새 노트', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildChip(String name, int count, bool selected) {
    final dark = context.read<NoteService>().globalDarkMode;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text('$name ($count)'),
        selected: selected,
        selectedColor: const Color(0xFFFFD54F),
        backgroundColor: dark ? const Color(0xFF3D3D3D) : Colors.grey[100],
        labelStyle: TextStyle(color: selected ? Colors.black : (dark ? Colors.white : Colors.black)),
        onSelected: (_) => setState(() => _activeFolder = name),
      ),
    );
  }

  void _openNote(UnmaskerNote note) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => EditorScreen(note: note)));
  }

  void _showFolderDialog(NoteService service) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('폴더 관리'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final f in service.folders)
          ListTile(title: Text(f), trailing: f != '기본' ? IconButton(icon: const Icon(Icons.delete, size: 20), onPressed: () { service.deleteFolder(f); Navigator.pop(ctx); }) : null),
      ]),
      actions: [
        TextButton(onPressed: () async {
          final ctrl = TextEditingController();
          final name = await showDialog<String>(context: ctx, builder: (_) => AlertDialog(
            title: const Text('새 폴더'), content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: '폴더 이름')),
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
