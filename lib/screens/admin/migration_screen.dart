import 'package:flutter/material.dart';
import '../../services/bible_data_migration.dart';

/// 관리자용 마이그레이션 화면
/// 개발/테스트 용도로만 사용
class MigrationScreen extends StatefulWidget {
  const MigrationScreen({super.key});

  @override
  State<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends State<MigrationScreen> {
  final BibleDataMigration _migration = BibleDataMigration();
  final List<String> _logs = [];
  bool _isRunning = false;
  MigrationResult? _result;

  void _addLog(String message) {
    setState(() {
      _logs.add('[${DateTime.now().toString().substring(11, 19)}] $message');
    });
  }

  Future<void> _runMigration() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _logs.clear();
      _result = null;
    });

    _addLog('마이그레이션 시작...');

    try {
      final result = await _migration.migrateAll(
        onProgress: (message) {
          _addLog(message);
        },
      );

      setState(() {
        _result = result;
        _isRunning = false;
      });

      _addLog('');
      _addLog('========== 결과 ==========');
      _addLog('성공: ${result.success}');
      _addLog('책: ${result.booksCreated}개');
      _addLog('챕터: ${result.chaptersCreated}개');
      _addLog('구절: ${result.versesCreated}개');
      _addLog('소요시간: ${result.durationMs}ms');
      if (result.error != null) {
        _addLog('오류: ${result.error}');
      }
    } catch (e) {
      _addLog('❌ 오류 발생: $e');
      setState(() {
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firestore 마이그레이션'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 상태 카드
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _isRunning
                ? Colors.orange.shade100
                : (_result?.success == true
                    ? Colors.green.shade100
                    : Colors.grey.shade100),
            child: Column(
              children: [
                Icon(
                  _isRunning
                      ? Icons.sync
                      : (_result?.success == true
                          ? Icons.check_circle
                          : Icons.cloud_upload),
                  size: 48,
                  color: _isRunning
                      ? Colors.orange
                      : (_result?.success == true ? Colors.green : Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  _isRunning
                      ? '마이그레이션 진행 중...'
                      : (_result?.success == true
                          ? '마이그레이션 완료!'
                          : '마이그레이션 대기 중'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_result != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '📚 ${_result!.booksCreated}권  📖 ${_result!.chaptersCreated}장  📝 ${_result!.versesCreated}절',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 로그 영역
          Expanded(
            child: Container(
              color: Colors.grey.shade900,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  Color textColor = Colors.white70;
                  if (log.contains('✅') || log.contains('✓')) {
                    textColor = Colors.greenAccent;
                  } else if (log.contains('❌') || log.contains('오류')) {
                    textColor = Colors.redAccent;
                  } else if (log.contains('⚠️')) {
                    textColor = Colors.orangeAccent;
                  } else if (log.contains('📚') || log.contains('📖')) {
                    textColor = Colors.cyanAccent;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      log,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: textColor,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 버튼
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isRunning ? null : _runMigration,
                icon: _isRunning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(
                  _isRunning ? '진행 중...' : '마이그레이션 실행',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          // 경고 메시지
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '주의: ESV API 호출로 인해 시간이 오래 걸릴 수 있습니다. (약 10-30분)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
