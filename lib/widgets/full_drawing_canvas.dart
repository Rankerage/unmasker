import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

enum DrawingTool { pen, highlighter, eraser, mask, unmask }

class MaskLayer {
  final List<MaskStroke> strokes;
  MaskLayer({List<MaskStroke>? strokes}) : strokes = strokes ?? [];

  Map<String, dynamic> toMap() => {
    'strokes': strokes.map((s) => s.toMap()).toList(),
  };

  factory MaskLayer.fromMap(Map<String, dynamic> map) {
    return MaskLayer(
      strokes: (map['strokes'] as List?)?.map((s) => MaskStroke.fromMap(s)).toList() ?? [],
    );
  }
}

class MaskStroke {
  final List<Offset> points;
  final double width;
  final double opacity;
  final bool isMask; // true = mask (hide), false = unmask (reveal)

  MaskStroke({required this.points, this.width = 20, this.opacity = 0.95, this.isMask = true});

  Map<String, dynamic> toMap() => {
    'points': points.map((p) => '${p.dx},${p.dy}').join(';'),
    'width': width, 'opacity': opacity, 'isMask': isMask,
  };

  factory MaskStroke.fromMap(Map<String, dynamic> map) {
    final pts = (map['points'] as String).split(';').map((s) {
      final p = s.split(','); return Offset(double.parse(p[0]), double.parse(p[1]));
    }).toList();
    return MaskStroke(points: pts, width: map['width'] ?? 20, opacity: map['opacity'] ?? 0.95, isMask: map['isMask'] ?? true);
  }
}

class FullDrawingCanvas extends StatefulWidget {
  final List<DrawingStroke> strokes;
  final ValueChanged<List<DrawingStroke>> onStrokesChanged;
  final void Function(DrawingStroke stroke, String strokeId)? onStrokeUpdated;
  final MaskLayer? maskLayer;
  final ValueChanged<MaskLayer>? onMaskChanged;
  final bool showMaskTools;

  const FullDrawingCanvas({
    super.key,
    required this.strokes,
    required this.onStrokesChanged,
    this.onStrokeUpdated,
    this.maskLayer,
    this.onMaskChanged,
    this.showMaskTools = false,
  });

  @override
  State<FullDrawingCanvas> createState() => _FullDrawingCanvasState();
}

class _FullDrawingCanvasState extends State<FullDrawingCanvas> {
  DrawingTool _currentTool = DrawingTool.pen;
  Color _currentColor = Colors.black;
  double _strokeWidth = 2.0;
  double _maskWidth = 20.0;
  double _maskOpacity = 0.95;
  List<Offset> _currentPoints = [];
  String _currentStrokeId = '';
  final _redoStack = <DrawingStroke>[];
  final _uuid = const Uuid();
  MaskLayer _maskLayer = MaskLayer();

  @override
  void initState() {
    super.initState();
    _maskLayer = widget.maskLayer ?? MaskLayer();
  }

  void _undo() {
    if (widget.strokes.isNotEmpty) {
      _redoStack.add(widget.strokes.removeLast());
      widget.onStrokesChanged(widget.strokes);
      setState(() {});
    }
  }

  void _redo() {
    if (_redoStack.isNotEmpty) {
      widget.strokes.add(_redoStack.removeLast());
      widget.onStrokesChanged(widget.strokes);
      setState(() {});
    }
  }

  void _clear() {
    _redoStack.clear();
    widget.strokes.clear();
    widget.onStrokesChanged(widget.strokes);
    setState(() {});
  }

  void _clearMasks() {
    _maskLayer = MaskLayer();
    widget.onMaskChanged?.call(_maskLayer);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: Stack(children: [
          Container(color: Colors.white),
          // 일반 그림 레이어
          GestureDetector(
            onPanStart: _isDrawingTool ? _onPanStart : null,
            onPanUpdate: _isDrawingTool ? _onPanUpdate : null,
            onPanEnd: _isDrawingTool ? _onPanEnd : null,
            child: CustomPaint(
              painter: FullCanvasPainter(
                strokes: widget.strokes,
                maskStrokes: _maskLayer.strokes,
                currentPoints: _currentPoints,
                currentColor: _currentColor,
                currentWidth: _strokeWidth,
                currentTool: _currentTool,
                maskWidth: _maskWidth,
                maskOpacity: _maskOpacity,
              ),
              size: Size.infinite,
            ),
          ),
          // 마스크 도구용 제스처 (별도 레이어 - 그리기 도구와 겹치지 않도록)
          if (!_isDrawingTool)
            GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: Container(color: Colors.transparent),
            ),
          Positioned(top: 8, right: 8, child: Column(children: [
            _miniBtn(Icons.undo, _undo), const SizedBox(height: 4),
            _miniBtn(Icons.redo, _redo), const SizedBox(height: 4),
            _miniBtn(Icons.delete_outline, _clear),
            if (_maskLayer.strokes.isNotEmpty) ...[
              const SizedBox(height: 8),
              _miniBtn(Icons.layers_clear, _clearMasks),
            ],
          ])),
        ]),
      ),
      FullToolbar(
        currentTool: _currentTool,
        currentColor: _currentColor,
        strokeWidth: _strokeWidth,
        maskWidth: _maskWidth,
        maskOpacity: _maskOpacity,
        onToolChanged: (t) => setState(() => _currentTool = t),
        onColorChanged: (c) => setState(() => _currentColor = c),
        onWidthChanged: (w) => setState(() => _strokeWidth = w),
        onMaskWidthChanged: (w) => setState(() => _maskWidth = w),
        onMaskOpacityChanged: (o) => setState(() => _maskOpacity = o),
        showMaskTools: widget.showMaskTools,
      ),
    ]);
  }

  bool get _isDrawingTool => _currentTool == DrawingTool.pen || _currentTool == DrawingTool.highlighter || _currentTool == DrawingTool.eraser;
  bool get _isMaskTool => _currentTool == DrawingTool.mask || _currentTool == DrawingTool.unmask;

  Widget _miniBtn(IconData icon, VoidCallback tap) {
    return Material(
      color: Colors.white, elevation: 2, borderRadius: BorderRadius.circular(20),
      child: InkWell(borderRadius: BorderRadius.circular(20), onTap: tap,
        child: Padding(padding: const EdgeInsets.all(6), child: Icon(icon, size: 18))),
    );
  }

  void _onPanStart(DragStartDetails d) {
    _currentPoints = [d.localPosition];
    _currentStrokeId = _uuid.v4();
    setState(() {});
    
    if (_isDrawingTool) {
      widget.onStrokeUpdated?.call(DrawingStroke(
        points: [d.localPosition],
        color: _currentTool == DrawingTool.eraser ? Colors.white : _currentColor,
        width: _currentTool == DrawingTool.highlighter ? _strokeWidth * 3 : _strokeWidth,
        tool: _currentTool,
      ), _currentStrokeId);
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    _currentPoints.add(d.localPosition);
    setState(() {});
    
    if (_isDrawingTool) {
      widget.onStrokeUpdated?.call(DrawingStroke(
        points: [d.localPosition],
        color: _currentTool == DrawingTool.eraser ? Colors.white : _currentColor,
        width: _currentTool == DrawingTool.highlighter ? _strokeWidth * 3 : _strokeWidth,
        tool: _currentTool,
      ), _currentStrokeId);
    }
  }

  void _onPanEnd(DragEndDetails d) {
    if (_currentPoints.isEmpty) return;
    
    if (_isMaskTool) {
      _maskLayer.strokes.add(MaskStroke(
        points: List.from(_currentPoints),
        width: _maskWidth,
        opacity: _maskOpacity,
        isMask: _currentTool == DrawingTool.mask,
      ));
      widget.onMaskChanged?.call(_maskLayer);
    } else if (_isDrawingTool && _currentPoints.length > 1) {
      widget.strokes.add(DrawingStroke(
        points: List.from(_currentPoints),
        color: _currentTool == DrawingTool.eraser ? Colors.white : _currentColor,
        width: _currentTool == DrawingTool.highlighter ? _strokeWidth * 3 : _strokeWidth,
        tool: _currentTool,
      ));
      widget.onStrokesChanged(widget.strokes);
    }
    _currentPoints = [];
    _currentStrokeId = '';
    _redoStack.clear();
    setState(() {});
  }
}

class DrawingStroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final DrawingTool tool;

  DrawingStroke({required this.points, required this.color, required this.width, required this.tool});

  Map<String, dynamic> toMap() => {
    'points': points.map((p) => '${p.dx},${p.dy}').join(';'),
    'color': color.value, 'width': width, 'tool': tool.index,
  };

  factory DrawingStroke.fromMap(Map<String, dynamic> map) {
    final pts = (map['points'] as String).split(';').map((s) {
      final p = s.split(','); return Offset(double.parse(p[0]), double.parse(p[1]));
    }).toList();
    return DrawingStroke(points: pts, color: Color(map['color']), width: (map['width'] as num).toDouble(), tool: DrawingTool.values[map['tool']]);
  }
}

class FullCanvasPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final List<MaskStroke> maskStrokes;
  final List<Offset> currentPoints;
  final Color currentColor;
  final double currentWidth;
  final DrawingTool currentTool;
  final double maskWidth;
  final double maskOpacity;

  FullCanvasPainter({
    required this.strokes, required this.maskStrokes, required this.currentPoints,
    required this.currentColor, required this.currentWidth, required this.currentTool,
    required this.maskWidth, required this.maskOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 일반 그림
    for (final stroke in strokes) {
      _drawSmoothStroke(canvas, stroke.points, stroke.color, stroke.width, stroke.tool);
    }
    if (currentPoints.length > 1 && (currentTool == DrawingTool.pen || currentTool == DrawingTool.highlighter || currentTool == DrawingTool.eraser)) {
      _drawSmoothStroke(canvas, currentPoints, currentColor, currentWidth, currentTool);
    }

    // 2. 마스크 레이어
    for (final ms in maskStrokes) {
      if (ms.points.length < 2) continue;
      final paint = Paint()
        ..color = ms.isMask ? Colors.black.withOpacity(ms.opacity) : Colors.transparent
        ..strokeWidth = ms.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..blendMode = ms.isMask ? BlendMode.srcOver : BlendMode.clear
        ..isAntiAlias = true;
      final path = Path()..moveTo(ms.points[0].dx, ms.points[0].dy);
      for (var i = 1; i < ms.points.length - 1; i++) {
        final mid = Offset((ms.points[i].dx + ms.points[i + 1].dx) / 2, (ms.points[i].dy + ms.points[i + 1].dy) / 2);
        path.quadraticBezierTo(ms.points[i].dx, ms.points[i].dy, mid.dx, mid.dy);
      }
      if (ms.points.length > 1) path.lineTo(ms.points.last.dx, ms.points.last.dy);
      canvas.drawPath(path, paint);
    }

    // 3. 현재 마스크/언마스크 미리보기
    if (currentPoints.length > 1 && (currentTool == DrawingTool.mask || currentTool == DrawingTool.unmask)) {
      final paint = Paint()
        ..color = currentTool == DrawingTool.mask ? Colors.black.withOpacity(maskOpacity * 0.5) : Colors.white.withOpacity(0.3)
        ..strokeWidth = maskWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(currentPoints[0].dx, currentPoints[0].dy);
      for (var i = 1; i < currentPoints.length; i++) path.lineTo(currentPoints[i].dx, currentPoints[i].dy);
      canvas.drawPath(path, paint);
    }
  }

  void _drawSmoothStroke(Canvas canvas, List<Offset> pts, Color color, double w, DrawingTool tool) {
    if (pts.length < 2) return;
    final paint = Paint()
      ..color = tool == DrawingTool.highlighter ? color.withOpacity(0.4) : color
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..blendMode = tool == DrawingTool.eraser ? BlendMode.clear : BlendMode.srcOver
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    if (pts.length == 2) { path.lineTo(pts[1].dx, pts[1].dy); }
    else {
      for (var i = 1; i < pts.length - 1; i++) {
        final mid = Offset((pts[i].dx + pts[i + 1].dx) / 2, (pts[i].dy + pts[i + 1].dy) / 2);
        path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
      }
      path.lineTo(pts.last.dx, pts.last.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant FullCanvasPainter old) => true;
}

// ===== 도구상자 =====
class FullToolbar extends StatelessWidget {
  final DrawingTool currentTool;
  final Color currentColor;
  final double strokeWidth;
  final double maskWidth;
  final double maskOpacity;
  final ValueChanged<DrawingTool> onToolChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onWidthChanged;
  final ValueChanged<double> onMaskWidthChanged;
  final ValueChanged<double> onMaskOpacityChanged;
  final bool showMaskTools;

  const FullToolbar({
    super.key, required this.currentTool, required this.currentColor,
    required this.strokeWidth, required this.maskWidth, required this.maskOpacity,
    required this.onToolChanged, required this.onColorChanged,
    required this.onWidthChanged, required this.onMaskWidthChanged,
    required this.onMaskOpacityChanged, required this.showMaskTools,
  });

  final _colors = [Colors.black, Colors.red, Colors.blue, Colors.green, Colors.orange, Colors.purple];

  @override
  Widget build(BuildContext context) {
    final isMask = currentTool == DrawingTool.mask || currentTool == DrawingTool.unmask;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // 도구 선택
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _toolBtn(DrawingTool.pen, Icons.edit, '펜'),
          _toolBtn(DrawingTool.highlighter, Icons.format_color_text, '형광펜'),
          _toolBtn(DrawingTool.eraser, Icons.auto_fix_normal, '지우개'),
          Container(width: 1, height: 24, color: Colors.grey[300]),
          _toolBtn(DrawingTool.mask, Icons.blur_on, '마스크'),
          _toolBtn(DrawingTool.unmask, Icons.blur_off, '언마스크'),
        ]),
        const Divider(height: 1),
        // 설정 패널
        if (isMask) ...[
          // 마스크 설정
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(children: [
              const Text('굵기: ', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(value: maskWidth, min: 5, max: 80, divisions: 15, onChanged: onMaskWidthChanged),
              ),
              Text('${maskWidth.toInt()}', style: const TextStyle(fontSize: 12)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              const Text('불투명: ', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(value: maskOpacity, min: 0.3, max: 1.0, divisions: 7, onChanged: onMaskOpacityChanged),
              ),
              Text('${(maskOpacity * 100).toInt()}%', style: const TextStyle(fontSize: 12)),
            ]),
          ),
        ] else ...[
          // 펜/형광펜 설정
          SizedBox(
            height: 32,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
              for (final c in _colors)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => onColorChanged(c),
                    child: Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(color: c, shape: BoxShape.circle,
                        border: currentColor.value == c.value ? Border.all(color: Colors.grey, width: 2) : null),
                    ),
                  ),
                ),
            ]),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(children: [
              _tb(DrawingTool.pen, Icons.edit_outlined, '펜'),
              _tb(DrawingTool.highlighter, Icons.format_color_text, '형광펜'),
              _tb(DrawingTool.eraser, Icons.auto_fix_normal, '지우개'),
              Container(width: 1, height: 20, color: Colors.grey[300]),
              _tb(DrawingTool.mask, Icons.blur_on, '마스크'),
              _tb(DrawingTool.unmask, Icons.blur_off, '언마스크'),
              Container(width: 1, height: 20, color: Colors.grey[300]),
              ...List.generate(4, (i) {
                final w = [1.5, 3.0, 5.0, 8.0][i];
                return GestureDetector(
                  onTap: () => onWidthChanged(w),
                  child: Container(
                    width: 32, height: 32, alignment: Alignment.center,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: strokeWidth == w ? Colors.grey[200] : Colors.transparent),
                    child: Container(width: w * 2.5, height: w * 2.5, decoration: BoxDecoration(shape: BoxShape.circle, color: currentColor)),
                  ),
                );
              }),
            ]),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _tb(DrawingTool tool, IconData icon, String label) {
    final sel = currentTool == tool;
    return GestureDetector(
      onTap: () => onToolChanged(tool),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(color: sel ? Colors.grey[200] : Colors.transparent, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 20, color: sel ? Colors.black87 : Colors.grey[500]),
      ),
    );
  }

  Widget _toolBtn(DrawingTool tool, IconData icon, String label) {
    final sel = currentTool == tool;
    return GestureDetector(
      onTap: () => onToolChanged(tool),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: sel ? Colors.grey[200] : Colors.transparent, borderRadius: BorderRadius.circular(8)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 22, color: sel ? Colors.black : Colors.grey[600]),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: sel ? Colors.black : Colors.grey[600])),
        ]),
      ),
    );
  }
}
