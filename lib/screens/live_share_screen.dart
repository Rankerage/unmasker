import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/live_session.dart';

class LiveShareScreen extends StatefulWidget {
  const LiveShareScreen({super.key});

  @override
  State<LiveShareScreen> createState() => _LiveShareScreenState();
}

class _LiveShareScreenState extends State<LiveShareScreen> {
  final LiveSession _session = LiveSession();
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController(text: '사용자');
  String _status = '';

  @override
  void initState() {
    super.initState();
    _session.onUserJoined = (u) => _showSnack('$u 님이 입장했습니다');
    _session.onUserLeft = (u) => _showSnack('$u 님이 퇴장했습니다');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  Future<void> _createRoom() async {
    final code = await _session.createRoom();
    setState(() { _codeCtrl.text = code; _status = '방 생성 완료'; });
  }

  Future<void> _joinRoom() async {
    final ok = await _session.joinRoom(_codeCtrl.text, _nameCtrl.text);
    setState(() { _status = ok ? '연결됨' : '연결 실패'; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('실시간 공유'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () { _session.leaveRoom(); Navigator.pop(context); },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 로고 영역
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD54F),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                children: [
                  Icon(Icons.people_outline, size: 48),
                  SizedBox(height: 8),
                  Text('Unmasker Live', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  Text('실시간으로 함께 필기하세요', style: TextStyle(fontSize: 14, color: Colors.black54)),
                ],
              ),
            ),
            const SizedBox(height: 32),

            if (!_session.connected) ...[
              // 방 만들기
              OutlinedButton.icon(
                onPressed: _createRoom,
                icon: const Icon(Icons.add),
                label: const Text('새 공유 세션 만들기'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),

              // 참가하기
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: '닉네임',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _codeCtrl,
                decoration: const InputDecoration(
                  labelText: '방 코드 (6자리)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.vpn_key_outlined),
                  hintText: '000000',
                ),
                maxLength: 6,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _joinRoom,
                icon: const Icon(Icons.login),
                label: const Text('참가하기'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: const Color(0xFFFFD54F),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ] else ...[
              // 연결됨 화면
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 48),
                    const SizedBox(height: 8),
                    const Text('연결됨', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    _infoRow('방 코드', _session.roomCode),
                    _infoRow('닉네임', _nameCtrl.text),
                    _infoRow('참가자', '${_session.participants.length}명'),
                    const SizedBox(height: 16),

                    // 방 코드 공유 버튼
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _session.roomCode));
                        _showSnack('방 코드가 복사되었습니다');
                      },
                      icon: const Icon(Icons.copy),
                      label: Text('코드 복사: ${_session.roomCode}'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () { _session.leaveRoom(); setState(() {}); },
                icon: const Icon(Icons.exit_to_app, color: Colors.red),
                label: const Text('나가기', style: TextStyle(color: Colors.red)),
              ),
            ],
            Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
