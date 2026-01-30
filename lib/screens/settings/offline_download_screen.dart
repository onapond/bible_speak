import 'package:flutter/material.dart';
import '../../services/offline/bible_offline_service.dart';
import '../../services/bible_data_service.dart';
import '../../domain/models/bible/bible_models.dart';

/// 오프라인 다운로드 관리 화면
class OfflineDownloadScreen extends StatefulWidget {
  const OfflineDownloadScreen({super.key});

  @override
  State<OfflineDownloadScreen> createState() => _OfflineDownloadScreenState();
}

class _OfflineDownloadScreenState extends State<OfflineDownloadScreen> {
  final BibleOfflineService _offlineService = BibleOfflineService();
  final BibleDataService _bibleService = BibleDataService.instance;

  List<Book> _books = [];
  StorageInfo _storageInfo = const StorageInfo(usedBytes: 0, bookCount: 0);
  bool _isLoading = true;

  static const _bgColor = Color(0xFF0F0F1A);
  static const _cardColor = Color(0xFF1E1E2E);
  static const _accentColor = Color(0xFF6C63FF);

  @override
  void initState() {
    super.initState();
    _initialize();
    _offlineService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _offlineService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) {
      _loadStorageInfo();
      setState(() {});
    }
  }

  Future<void> _initialize() async {
    await _offlineService.initialize();
    await _loadBooks();
    await _loadStorageInfo();
    setState(() => _isLoading = false);
  }

  Future<void> _loadBooks() async {
    _books = await _bibleService.getBooks();
  }

  Future<void> _loadStorageInfo() async {
    _storageInfo = await _offlineService.getStorageInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '오프라인 다운로드',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accentColor))
          : Column(
              children: [
                // 저장 공간 정보
                _buildStorageInfo(),

                // 안내 메시지
                _buildInfoBanner(),

                // 책 목록
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _books.length,
                    itemBuilder: (context, index) {
                      return _buildBookTile(_books[index]);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStorageInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.storage,
              color: _accentColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '저장된 성경책',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_storageInfo.bookCount}권 (약 ${_storageInfo.usedMB}MB)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (_storageInfo.bookCount > 0)
            TextButton(
              onPressed: _showClearAllDialog,
              child: Text(
                '전체 삭제',
                style: TextStyle(
                  color: Colors.red.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.blue.withValues(alpha: 0.8),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '다운로드한 성경은 인터넷 없이도 읽을 수 있습니다.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookTile(Book book) {
    final isCached = _offlineService.isBookCached(book.id);
    final progress = _offlineService.getDownloadProgress(book.id);
    final isDownloading = progress?.status == DownloadStatus.downloading;
    final meta = _offlineService.getBookMeta(book.id);

    return Semantics(
      button: true,
      label: '${book.nameKo}, ${isCached ? "다운로드됨" : "다운로드 안됨"}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCached ? _accentColor.withValues(alpha: 0.3) : Colors.white10,
          ),
        ),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isCached
                      ? _accentColor.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    isCached ? Icons.check_circle : Icons.menu_book,
                    color: isCached ? _accentColor : Colors.white54,
                    size: 24,
                  ),
                ),
              ),
              title: Text(
                book.nameKo,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${book.chapterCount}장 · ${book.testament == "OT" ? "구약" : "신약"}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                  if (isCached && meta != null)
                    Text(
                      '다운로드: ${_formatDate(meta['downloadedAt'])}',
                      style: TextStyle(
                        color: _accentColor.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
              trailing: _buildActionButton(book, isCached, isDownloading, progress),
            ),

            // 다운로드 진행률
            if (isDownloading && progress != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress.progress,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(_accentColor),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      progress.message,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    Book book,
    bool isCached,
    bool isDownloading,
    DownloadProgress? progress,
  ) {
    if (isDownloading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: _accentColor,
        ),
      );
    }

    if (isCached) {
      return PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.white54),
        color: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'redownload',
            child: Row(
              children: [
                const Icon(Icons.refresh, color: Colors.white70, size: 20),
                const SizedBox(width: 12),
                const Text('다시 다운로드', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, color: Colors.red.shade300, size: 20),
                const SizedBox(width: 12),
                Text('삭제', style: TextStyle(color: Colors.red.shade300)),
              ],
            ),
          ),
        ],
        onSelected: (value) {
          if (value == 'delete') {
            _showDeleteDialog(book);
          } else if (value == 'redownload') {
            _downloadBook(book);
          }
        },
      );
    }

    return IconButton(
      icon: const Icon(Icons.download, color: _accentColor),
      onPressed: () => _downloadBook(book),
      tooltip: '다운로드',
    );
  }

  String _formatDate(int? timestamp) {
    if (timestamp == null) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _downloadBook(Book book) async {
    final success = await _offlineService.downloadBook(book.id);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${book.nameKo} 다운로드 완료'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${book.nameKo} 다운로드 실패'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _showDeleteDialog(Book book) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('오프라인 데이터 삭제', style: TextStyle(color: Colors.white)),
        content: Text(
          '${book.nameKo}의 오프라인 데이터를 삭제하시겠습니까?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _offlineService.deleteBook(book.id);
              await _loadStorageInfo();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${book.nameKo} 삭제됨'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('전체 삭제', style: TextStyle(color: Colors.white)),
        content: Text(
          '모든 오프라인 성경 데이터를 삭제하시겠습니까?\n${_storageInfo.bookCount}권의 데이터가 삭제됩니다.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _offlineService.clearAll();
              await _loadStorageInfo();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('모든 오프라인 데이터가 삭제되었습니다'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            child: const Text('전체 삭제'),
          ),
        ],
      ),
    );
  }
}
