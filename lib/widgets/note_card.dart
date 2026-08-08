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

  // 삼성노트 파스텔 카드 색상
  static const List<Color> cardColors = [
    Color(0xFFFFF9C4), // 연노랑
    Color(0xFFF3E5F5), // 연보라
    Color(0xFFE8F5E9), // 연초록
    Color(0xFFE3F2FD), // 연파랑
    Color(0xFFFFF3E0), // 연주황
    Color(0xFFFFEBEE), // 연분홍
  ];

  @override
  Widget build(BuildContext context) {
    final color = cardColors[note.id.hashCode.abs() % cardColors.length];
    final dateStr = DateFormat('yy.MM.dd').format(note.updatedAt);
    final hasContent = note.content.isNotEmpty;
    final hasDrawing = note.drawingStrokes.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined, color: Colors.grey[700]),
                title: Text(isPinned ? '고정 해제' : '상단 고정', style: const TextStyle(fontSize: 15)),
                onTap: () { onTogglePin(); Navigator.pop(ctx); },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined, color: Colors.grey),
                title: const Text('공유', style: TextStyle(fontSize: 15)),
                onTap: () { Navigator.pop(ctx); },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('삭제', style: TextStyle(fontSize: 15, color: Colors.red)),
                onTap: () { onDelete(); Navigator.pop(ctx); },
              ),
            ]),
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 3, offset: const Offset(0, 1))],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목 + 핀
            Row(children: [
              Expanded(
                child: Text(
                  note.title.isEmpty ? '새 노트' : note.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87),
                ),
              ),
              if (isPinned) const Icon(Icons.push_pin, size: 14, color: Colors.black38),
            ]),
            const SizedBox(height: 6),
            // 미리보기
            Expanded(
              child: hasDrawing
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CustomPaint(
                        painter: _ThumbPainter(note.drawingStrokes),
                        size: Size.infinite,
                      ),
                    )
                  : note.imagePaths.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(File(note.imagePaths.first), fit: BoxFit.cover, width: double.infinity),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hasContent)
                              Expanded(
                                child: Text(note.content, maxLines: 4, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.5)),
                              ),
                          ],
                        ),
            ),
            const SizedBox(height: 6),
            // 하단 정보
            Row(children: [
              if (note.audioPath != null) const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.mic, size: 13, color: Color(0xFFE57373)),
              ),
              if (note.imagePaths.isNotEmpty) const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.image_outlined, size: 13, color: Color(0xFF64B5F6)),
              ),
              if (note.pdfPath != null) const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.picture_as_pdf_outlined, size: 13, color: Color(0xFFE57373)),
              ),
              if (hasDrawing) const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.draw_outlined, size: 13, color: Color(0xFF9575CD)),
              ),
              const Spacer(),
              Text(dateStr, style: const TextStyle(fontSize: 11, color: Colors.black38)),
            ]),
          ],
        ),
      ),
    );
  }
}

class _ThumbPainter extends CustomPainter {
  final List<Map<String, dynamic>> strokes;
  _ThumbPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 200;
    for (final s in strokes) {
      final pts = (s['points'] as String?)?.split(';').map((p) {
            final xy = p.split(','); return Offset(double.parse(xy[0]) * scale, double.parse(xy[1]) * scale);
          }).toList() ?? [];
      if (pts.length < 2) continue;
      final paint = Paint()
        ..color = Color(s['color'] ?? 0xFF000000).withOpacity(0.7)
        ..strokeWidth = ((s['width'] ?? 2.0) as num).toDouble() * scale
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (var i = 1; i < pts.length; i++) path.lineTo(pts[i].dx, pts[i].dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ThumbPainter old) => true;
}
