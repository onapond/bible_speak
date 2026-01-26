import 'package:flutter/material.dart';
import '../../domain/models/bible/bible_models.dart';
import '../../services/auth_service.dart';
import '../../services/bible_data_service.dart';
import 'chapter_selection_screen.dart';

/// 성경책 선택 화면
class BookSelectionScreen extends StatefulWidget {
  final AuthService authService;

  const BookSelectionScreen({
    super.key,
    required this.authService,
  });

  @override
  State<BookSelectionScreen> createState() => _BookSelectionScreenState();
}

class _BookSelectionScreenState extends State<BookSelectionScreen> {
  late Future<List<Book>> _booksFuture;

  @override
  void initState() {
    super.initState();
    _booksFuture = BibleDataService.instance.getBooks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('성경책 선택'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: FutureBuilder<List<Book>>(
        future: _booksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text('데이터를 불러올 수 없습니다\n${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _booksFuture = BibleDataService.instance.getBooks();
                      });
                    },
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          final books = snapshot.data ?? [];

          // 구약/신약 분류
          final oldTestament = books.where((b) => b.testament == 'OT').toList();
          final newTestament = books.where((b) => b.testament == 'NT').toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Firestore 상태 표시 (디버그용, 나중에 제거)
              if (BibleDataService.instance.isUsingLocalFallback)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.amber),
                      SizedBox(width: 8),
                      Text('로컬 데이터 사용 중', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),

              // 구약
              if (oldTestament.isNotEmpty) ...[
                _buildSectionHeader('구약성경', Icons.menu_book, Colors.brown),
                const SizedBox(height: 12),
                ...oldTestament.map((book) => _buildBookCard(context, book)),
                const SizedBox(height: 24),
              ],

              // 신약
              if (newTestament.isNotEmpty) ...[
                _buildSectionHeader('신약성경', Icons.auto_stories, Colors.indigo),
                const SizedBox(height: 12),
                ...newTestament.map((book) => _buildBookCard(context, book)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildBookCard(BuildContext context, Book book) {
    final isOldTestament = book.testament == 'OT';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToChapterSelection(context, book),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 책 아이콘
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isOldTestament
                        ? [Colors.brown.shade300, Colors.brown.shade600]
                        : [Colors.indigo.shade300, Colors.indigo.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    book.nameKo[0], // 첫 글자
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // 책 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          book.nameKo,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (book.isFree) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '무료',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${book.nameEn} - ${book.chapterCount}장',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // 화살표
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToChapterSelection(BuildContext context, Book book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChapterSelectionScreen(
          authService: widget.authService,
          book: book,
        ),
      ),
    );
  }
}
