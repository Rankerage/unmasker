import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';
import '../models/note.dart';
import '../widgets/full_drawing_canvas.dart';
import '../services/live_session.dart';
import 'live_share_screen.dart';

class EditorScreen extends StatefulWidget {
  final UnmaskerNote note;
  const EditorScreen({super.key, required this.note});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  String _selectedFolder = '기본';
  bool _showDrawing = false;
  List<DrawingStroke> _strokes = [];
  List<DrawingStroke> _remoteStrokes = [];
  MaskLayer _maskLayer = MaskLayer();
  final Map<String, List<Offset>> _remotePoints = {};
  final Map<String, Color> _remoteStrokeColors = {};
  final Map<String, double> _remoteStrokeWidths = {};
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  bool _isRecording = false;
  String? _recordingPath;

  // 라이브 세션
  LiveSession? _liveSession;
  String _liveStatus = '';

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.note.title);
    _contentCtrl = TextEditingController(text: _stripFormatTags(widget.note.content));
    _selectedFolder = widget.note.folder;
  }

  String _stripFormatTags(String text) {
    return text.replaceAll('[B]', '').replaceAll('[/B]', '')
        .replaceAll('[I]', '').replaceAll('[/I]', '')
        .replaceAll('[U]', '').replaceAll('[/U]', '');
  }

  @override
  void dispose() {
    _saveNote();
    _titleCtrl.dispose(); _contentCtrl.dispose();
    _recorder.dispose(); _player.dispose();
    _liveSession?.leaveRoom();
    super.dispose();
  }

  void _saveNote() {
    final service = context.read<NoteService>();
    if (widget.note.title.isEmpty && _titleCtrl.text.isEmpty && _contentCtrl.text.isEmpty) return;
    if (widget.note.title.isEmpty) {
      service.addNote(UnmaskerNote(
        title: _titleCtrl.text, content: _contentCtrl.text,
        folder: _selectedFolder, hasDrawing: _showDrawing,
        drawingStrokes: _strokes.map((s) => s.toMap()).toList(),
      ));
    } else {
      service.updateNote(widget.note.id, title: _titleCtrl.text, content: _contentCtrl.text, folder: _selectedFolder);
    }
  }

  void _applyFormat(String tag) {
    final sel = _contentCtrl.selection;
    if (!sel.isValid || sel.start == sel.end) return;
    final text = _contentCtrl.text;
    final selected = text.substring(sel.start, sel.end);
    final formatted = '[$tag]$selected[/$tag]';
    _contentCtrl.text = text.substring(0, sel.start) + formatted + text.substring(sel.end);
    _contentCtrl.selection = TextSelection.collapsed(offset: sel.start + formatted.length);
    _saveNote();
  }

  Future<void> _pickImage() async {
    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      final ins = _contentCtrl.selection.baseOffset;
      _contentCtrl.text = '${_contentCtrl.text.substring(0, ins)}[IMG:${file.path}]${_contentCtrl.text.substring(ins)}';
      _saveNote();
    }
  }

  Future<void> _importPDF() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result != null) {
      _contentCtrl.text += '\n[PDF:${result.files.single.path!}]';
      _saveNote();
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      _recordingPath = await _recorder.stop();
      _isRecording = false;
      _contentCtrl.text += '\n[REC:$_recordingPath]';
      _saveNote();
    } else {
      if (await _recorder.hasPermission()) {
        await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc));
        _isRecording = true;
      }
    }
    setState(() {});
  }

  void _playAudio(String path) {
    if (path.isNotEmpty) _player.play(DeviceFileSource(path));
  }

  void _shareNote() {
    Share.share('${_titleCtrl.text}\n\n${_contentCtrl.text}', subject: _titleCtrl.text);
  }

  void _confirmDelete() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('노트 삭제'), content: const Text('이 노트를 삭제할까요?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
        TextButton(onPressed: () { context.read<NoteService>().deleteNote(widget.note.id); Navigator.pop(ctx); Navigator.pop(context); },
          child: const Text('삭제', style: TextStyle(color: Colors.red))),
      ],
    ));
  }

  // ========== 실시간 공유 ==========
  void _startLiveShare() async {
    final nameCtrl = TextEditingController(text: '사용자');
    final codeCtrl = TextEditingController();

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('실시간 공유', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '닉네임', prefixIcon: Icon(Icons.person))),
            const SizedBox(height: 8),
            TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: '방 코드 (6자리)', prefixIcon: Icon(Icons.vpn_key), hintText: '빈칸이면 새로 생성')),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx, 'create'), child: const Text('새로 만들기'))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(onPressed: () => Navigator.pop(ctx, 'join'), child: const Text('참가하기'))),
            ]),
          ]),
        ),
      ),
    );

    if (result == null) return;

    final session = LiveSession();
    _liveSession = session;

    session.onRemotePoint = (x, y, user, strokeId) {
      setState(() {
        // 진행 중인 원격 획에 포인트 추가
        final existing = _remotePoints[strokeId];
        if (existing != null) {
          existing.add(Offset(x, y));
        } else {
          _remotePoints[strokeId] = [Offset(x, y)];
        }
      });
    };
    session.onRemoteStrokeEnd = (strokeId, user) {
      setState(() {
        final pts = _remotePoints.remove(strokeId);
        if (pts != null && pts.length > 0) {
          _remoteStrokes.add(DrawingStroke(
            points: pts,
            color: _remoteStrokeColors[strokeId] ?? Colors.red,
            width: _remoteStrokeWidths[strokeId] ?? 2.0,
            tool: DrawingTool.pen,
          ));
          _remoteStrokeColors.remove(strokeId);
          _remoteStrokeWidths.remove(strokeId);
        }
      });
    };
    session.onRemoteUndo = () {
      setState(() { if (_strokes.isNotEmpty) _strokes.removeLast(); });
    };
    session.onRemoteClear = () {
      setState(() { _strokes.clear(); _remoteStrokes.clear(); });
    };
    session.onRemoteTextUpdate = (text, user) {
      _contentCtrl.text = text;
      _showToast('$user 텍스트 편집');
    };
    session.onUserJoined = (user) => _showToast('$user 입장');
    session.onUserLeft = (user) => _showToast('$user 퇴장');
    session.onInit = (strokes, text) {
      setState(() {
        _remoteStrokes = strokes.map((s) => DrawingStroke.fromMap(s)).toList();
        if (text.isNotEmpty) _contentCtrl.text = text;
      });
      _liveStatus = '${session.participants.length}명 연결됨';
    };

    bool ok;
    if (result == 'create') {
      final code = await session.createRoom();
      ok = await session.joinRoom(code, nameCtrl.text);
      if (ok) _showToast('방 생성됨: $code (코드 복사됨)\n친구에게 공유하세요!');
      Clipboard.setData(ClipboardData(text: code));
    } else {
      ok = await session.joinRoom(codeCtrl.text, nameCtrl.text);
      if (ok) _showToast('연결됨!');
    }

    setState(() { _liveStatus = ok ? '${session.participants.length}명 연결됨' : ''; });
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<NoteService>().globalDarkMode;
    final liveConnected = _liveSession?.connected ?? false;

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF1A1A1A) : Colors.white,
      appBar: AppBar(
        backgroundColor: dark ? const Color(0xFF2D2D2D) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: dark ? Colors.white : Colors.black),
          onPressed: () { _saveNote(); _liveSession?.leaveRoom(); Navigator.pop(context); },
        ),
        title: liveConnected
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(_liveStatus, style: TextStyle(fontSize: 14, color: dark ? Colors.white : Colors.black)),
              ])
            : const Text(''),
        actions: [
          IconButton(
            icon: Icon(liveConnected ? Icons.people : Icons.people_outline, color: liveConnected ? Colors.green : (dark ? Colors.white : Colors.black)),
            onPressed: liveConnected ? () { _liveSession?.leaveRoom(); setState(() => _liveStatus = ''); _showToast('공유 종료'); } : _startLiveShare,
          ),
          PopupMenuButton(
            icon: Icon(Icons.more_vert, color: dark ? Colors.white : Colors.black),
            itemBuilder: (ctx) => [
              PopupMenuItem(child: const Text('삭제'), onTap: _confirmDelete),
              PopupMenuItem(child: const Text('공유'), onTap: _shareNote),
              PopupMenuItem(child: const Text('PDF로 저장'), onTap: () {}),
            ],
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _titleCtrl,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: dark ? Colors.white : Colors.black),
            decoration: InputDecoration(hintText: '제목', border: InputBorder.none, hintStyle: TextStyle(color: dark ? Colors.grey[600] : Colors.grey[400])),
            onChanged: (_) => _saveNote(),
          ),
        ),
        Divider(height: 1, color: dark ? Colors.grey[800] : Colors.grey[200]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(children: [
            Icon(Icons.folder_outlined, size: 16, color: dark ? Colors.grey[500] : Colors.grey),
            const SizedBox(width: 4),
            Text(_selectedFolder, style: TextStyle(color: dark ? Colors.grey[500] : Colors.grey, fontSize: 13)),
            const Spacer(),
            if (liveConnected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Text('LIVE', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            const SizedBox(width: 8),
            Text('${_contentCtrl.text.length}자', style: TextStyle(color: dark ? Colors.grey[500] : Colors.grey, fontSize: 12)),
          ]),
        ),
        Divider(height: 1, color: dark ? Colors.grey[800] : Colors.grey[200]),
        Expanded(
          child: _showDrawing
              : Stack(children: [
                  FullDrawingCanvas(
                    strokes: _strokes,
                    onStrokesChanged: (s) { _strokes = s; },
                    onStrokeUpdated: (stroke, strokeId) {
                      if (liveConnected) {
                        final p = stroke.points.first;
                        _liveSession?.sendPoint(p.dx, p.dy, strokeId, stroke.color, stroke.width, stroke.tool.name);
                      }
                    },
                    maskLayer: _maskLayer,
                    onMaskChanged: (m) => _maskLayer = m,
                    showMaskTools: true,
                  ),
                  // 원격 미완료 포인트 + 완료된 획 렌더링
                  if (_remotePoints.isNotEmpty || _remoteStrokes.isNotEmpty)
                    IgnorePointer(
                      child: CustomPaint(
                        painter: RemoteLivePainter(_remoteStrokes, _remotePoints),
                        size: Size.infinite,
                      ),
                    ),
                ])
              : _buildRichTextEditor(dark),
        ),
        _buildBottomToolbar(dark),
      ]),
    );
  }

  Widget _buildRichTextEditor(bool dark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: _contentCtrl,
        maxLines: null, expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: TextStyle(fontSize: 16, height: 1.6, color: dark ? Colors.white : Colors.black),
        decoration: InputDecoration(hintText: '노트를 작성하세요...', border: InputBorder.none, hintStyle: TextStyle(color: dark ? Colors.grey[600] : Colors.grey[400])),
        onChanged: (v) {
          _saveNote();
          if (_liveSession?.connected ?? false) _liveSession?.sendTextUpdate(v);
        },
      ),
    );
  }

  Widget _buildBottomToolbar(bool dark) {
    return Container(
      decoration: BoxDecoration(color: dark ? const Color(0xFF2D2D2D) : Colors.white, border: Border(top: BorderSide(color: dark ? Colors.grey[800]! : Colors.grey[200]!))),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _tbBtn(Icons.format_bold, '굵게', dark, onTap: () => _applyFormat('B')),
            _tbBtn(Icons.format_italic, '기울임', dark, onTap: () => _applyFormat('I')),
            _tbBtn(Icons.format_underlined, '밑줄', dark, onTap: () => _applyFormat('U')),
            _tbBtn(Icons.format_list_bulleted, '목록', dark),
            Container(width: 1, height: 24, color: Colors.grey[600]),
            _tbBtn(_showDrawing ? Icons.text_fields : Icons.draw, _showDrawing ? '텍스트' : '그리기', dark, onTap: () => setState(() => _showDrawing = !_showDrawing)),
            _tbBtn(_isRecording ? Icons.mic : Icons.mic_none, _isRecording ? '중지' : '녹음', dark, onTap: _toggleRecording),
            _tbBtn(Icons.image_outlined, '사진', dark, onTap: _pickImage),
            _tbBtn(Icons.picture_as_pdf, 'PDF', dark, onTap: _importPDF),
          ]),
        ),
      ),
    );
  }

  Widget _tbBtn(IconData icon, String label, bool dark, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 22, color: dark ? Colors.grey[400] : Colors.grey[700]),
          Text(label, style: TextStyle(fontSize: 10, color: dark ? Colors.grey[400] : Colors.grey[600])),
        ]),
      ),
    );
  }
}

class RemoteLivePainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final Map<String, List<Offset>> activePoints;

  RemoteLivePainter(this.strokes, this.activePoints);

  @override
  void paint(Canvas canvas, Size size) {
    // 완료된 획
    for (final s in strokes) {
      if (s.points.length < 2) continue;
      final paint = Paint()
        ..color = s.color.withOpacity(0.5)
        ..strokeWidth = s.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high;
      final path = Path()..moveTo(s.points[0].dx, s.points[0].dy);
      for (var i = 1; i < s.points.length; i++) {
        final mid = Offset((s.points[i].dx + (i+1 < s.points.length ? s.points[i+1].dx : s.points[i].dx)) / 2,
                           (s.points[i].dy + (i+1 < s.points.length ? s.points[i+1].dy : s.points[i].dy)) / 2);
        path.quadraticBezierTo(s.points[i].dx, s.points[i].dy, mid.dx, mid.dy);
      }
      canvas.drawPath(path, paint);
    }
    
    // 진행 중인 포인트들 (실시간 스트리밍)
    for (final pts in activePoints.values) {
      if (pts.length < 2) {
        // 단일 포인트는 점으로
        if (pts.isNotEmpty) {
          final p = pts.first;
          final paint = Paint()..color = Colors.red.withOpacity(0.5)..strokeWidth = 3..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
          canvas.drawCircle(p, 2, paint);
        }
        continue;
      }
      final paint = Paint()
        ..color = Colors.red.withOpacity(0.4)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (var i = 1; i < pts.length - 1; i++) {
        final mid = Offset((pts[i].dx + pts[i + 1].dx) / 2, (pts[i].dy + pts[i + 1].dy) / 2);
        path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
      }
      if (pts.length > 1) path.lineTo(pts.last.dx, pts.last.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant RemoteLivePainter old) => activePoints != old.activePoints || strokes != old.strokes;
}
