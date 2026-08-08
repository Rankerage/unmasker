import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';

class NoteCard extends StatelessWidget {
  final UnmaskerNote note;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  const NoteCard({
    super.key, required this.note, required this.isPinned,
    required this.onTap, required this.onTogglePin, required this.onDelete,
  });

  final List<Color> _cardColors = const [
    Color(0xFFFFF9C4), Color(0xFFF3E5F5), Color(0xFFE8F5E9),
    Color(0xFFE3F2FD), Color(0xFFFFF3E0),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = false; // handled by parent
    final color = _cardColors[note.id.hashCode.abs() % _cardColors.length];
    final dateStr = DateFormat('yy.MM.dd').format(note.updatedAt);

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => showModalBottomSheet(context: context, builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined),
            title: Text(isPinned ? '고정 해제' : '고정'), onTap: () { onTogglePin(); Navigator.pop(ctx); }),
          ListTile(leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('삭제', style: TextStyle(color: Colors.red)), onTap: () { onDelete(); Navigator.pop(ctx); }),
        ]),
      )),
      child: Container(
        decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(note.title.isEmpty ? '새 노트' : note.title,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
            if (isPinned) const Icon(Icons.push_pin, size: 14, color: Colors.grey),
          ]),
          const SizedBox(height: 4),
          Expanded(
            child: note.hasDrawing && note.drawingStrokes.isNotEmpty
                ? CustomPaint(
                    painter: _ThumbnailPainter(note.drawingStrokes),
                    size: Size.infinite,
                  )
                : note.imagePaths.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(note.imagePaths.first), fit: BoxFit.cover, width: double.infinity),
                      )
                    : note.audioPath != null
                        ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.mic, color: Colors.red, size: 28), SizedBox(height: 2),
                            Text('녹음 있음', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ])
                        : note.pdfPath != null
                            ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.picture_as_pdf, color: Colors.red, size: 28), SizedBox(height: 2),
                                Text('PDF 있음', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              ])
                            : Text(
                                note.content.isEmpty ? '내용을 입력하세요' : note.content,
                                maxLines: 4, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                              ),
          ),
          const SizedBox(height: 4),
          Row(children: [
            if (note.audioPath != null) const Icon(Icons.mic, size: 12, color: Colors.red),
            if (note.imagePaths.isNotEmpty) const Icon(Icons.image, size: 12, color: Colors.blue),
            if (note.pdfPath != null) const Icon(Icons.picture_as_pdf, size: 12, color: Colors.red),
            if (note.hasDrawing) const Icon(Icons.draw, size: 12, color: Colors.purple),
            const Spacer(),
            Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ]),
        ]),
      ),
    );
  }
}

class _ThumbnailPainter extends CustomPainter {
  final List<Map<String, dynamic>> strokes;
  _ThumbnailPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 200;
    for (final s in strokes) {
      final pts = (s['points'] as String?)?.split(';').map((p) {
            final xy = p.split(',');
            return Offset(double.parse(xy[0]) * scale, double.parse(xy[1]) * scale);
          }).toList() ?? [];
      if (pts.length < 2) continue;
      final paint = Paint()
        ..color = Color(s['color'] ?? 0xFF000000)
        ..strokeWidth = ((s['width'] ?? 2.0) as num).toDouble() * scale
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (var i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ThumbnailPainter old) => true;
}
