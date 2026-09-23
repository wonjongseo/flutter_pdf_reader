import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PdfReaderApp());
}

// =========================================================
// APP
// =========================================================

class PdfReaderApp extends StatelessWidget {
  const PdfReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'iPad PDF Reader',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const HomeScreen(),
    );
  }
}

// =========================================================
// PDF 정보 모델
// =========================================================

class PdfItem {
  final String id;
  final String name;
  final String path;

  int lastPage;
  int totalPages;

  List<int> bookmarks;

  int lastOpenedAt;

  PdfItem({
    required this.id,
    required this.name,
    required this.path,
    this.lastPage = 0,
    this.totalPages = 0,
    List<int>? bookmarks,
    this.lastOpenedAt = 0,
  }) : bookmarks = bookmarks ?? [];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'lastPage': lastPage,
      'totalPages': totalPages,
      'bookmarks': bookmarks,
      'lastOpenedAt': lastOpenedAt,
    };
  }

  factory PdfItem.fromJson(Map<String, dynamic> json) {
    return PdfItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      path: json['path'] ?? '',
      lastPage: json['lastPage'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
      bookmarks: List<int>.from(json['bookmarks'] ?? []),
      lastOpenedAt: json['lastOpenedAt'] ?? 0,
    );
  }
}

// =========================================================
// PDF 저장소
// =========================================================

class PdfStorage {
  static const String _key = 'pdf_library';

  // -------------------------------------------------------
  // 목록 불러오기
  // -------------------------------------------------------

  static Future<List<PdfItem>> load() async {
    final prefs = await SharedPreferences.getInstance();

    final text = prefs.getString(_key);

    if (text == null || text.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> data = jsonDecode(text);

      return data
          .map((e) => PdfItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // -------------------------------------------------------
  // 목록 저장
  // -------------------------------------------------------

  static Future<void> save(List<PdfItem> items) async {
    final prefs = await SharedPreferences.getInstance();

    final text = jsonEncode(items.map((e) => e.toJson()).toList());

    await prefs.setString(_key, text);
  }
}

// =========================================================
// HOME
// =========================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<PdfItem> _pdfList = [];

  bool _loading = true;
  bool _isPicking = false;

  @override
  void initState() {
    super.initState();

    _loadLibrary();
  }

  // =======================================================
  // 라이브러리 불러오기
  // =======================================================

  Future<void> _loadLibrary() async {
    final list = await PdfStorage.load();

    // 최근 본 PDF가 위로
    list.sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));

    if (!mounted) {
      return;
    }

    setState(() {
      _pdfList = list;
      _loading = false;
    });
  }

  // =======================================================
  // PDF 선택
  // =======================================================

  Future<void> _pickPdf() async {
    if (_isPicking) {
      return;
    }

    setState(() {
      _isPicking = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (!mounted) {
        return;
      }

      if (result == null || result.files.isEmpty) {
        return;
      }

      final selected = result.files.first;

      final originalPath = selected.path;

      if (originalPath == null) {
        _showMessage('PDF 파일 경로를 가져올 수 없습니다.');

        return;
      }

      // ---------------------------------------------------
      // 앱 내부 Documents에 PDF 복사
      // ---------------------------------------------------

      final directory = await getApplicationDocumentsDirectory();

      final pdfDirectory = Directory('${directory.path}/pdf_library');

      if (!await pdfDirectory.exists()) {
        await pdfDirectory.create(recursive: true);
      }

      // 같은 이름의 PDF인지 확인
      PdfItem? existingItem;

      for (final item in _pdfList) {
        if (item.name == selected.name) {
          existingItem = item;
          break;
        }
      }

      // 이미 추가되어 있으면 기존 PDF 열기
      if (existingItem != null) {
        await _openPdf(existingItem);

        return;
      }

      // ---------------------------------------------------
      // 고유 ID
      // ---------------------------------------------------

      final id = DateTime.now().microsecondsSinceEpoch.toString();

      final extension = selected.name.toLowerCase().endsWith('.pdf')
          ? '.pdf'
          : '';

      final targetPath = '${pdfDirectory.path}/$id$extension';

      // ---------------------------------------------------
      // 파일 복사
      // ---------------------------------------------------

      await File(originalPath).copy(targetPath);

      final item = PdfItem(
        id: id,
        name: selected.name,
        path: targetPath,
        lastOpenedAt: DateTime.now().millisecondsSinceEpoch,
      );

      _pdfList.insert(0, item);

      await PdfStorage.save(_pdfList);

      if (!mounted) {
        return;
      }

      setState(() {});

      await _openPdf(item);
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage('PDF 선택 중 오류가 발생했습니다.\n$e');
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
        });
      }
    }
  }

  // =======================================================
  // PDF 열기
  // =======================================================

  Future<void> _openPdf(PdfItem item) async {
    if (!await File(item.path).exists()) {
      _showMessage('PDF 파일을 찾을 수 없습니다.');

      return;
    }

    item.lastOpenedAt = DateTime.now().millisecondsSinceEpoch;

    await PdfStorage.save(_pdfList);

    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          item: item,

          onChanged: () async {
            await PdfStorage.save(_pdfList);
          },
        ),
      ),
    );

    // 돌아오면 최근 사용 순으로 다시 정렬
    _pdfList.sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));

    await PdfStorage.save(_pdfList);

    if (mounted) {
      setState(() {});
    }
  }

  // =======================================================
  // PDF 삭제
  // =======================================================

  Future<void> _deletePdf(PdfItem item) async {
    final result = await showDialog<bool>(
      context: context,

      builder: (context) {
        return AlertDialog(
          title: const Text('PDF 삭제'),

          content: Text(
            '${item.name}\n\n'
            '목록과 앱 내부에 저장된 PDF를 삭제하시겠습니까?',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('취소'),
            ),

            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (result != true) {
      return;
    }

    try {
      final file = File(item.path);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    _pdfList.removeWhere((e) => e.id == item.id);

    await PdfStorage.save(_pdfList);

    if (mounted) {
      setState(() {});
    }
  }

  // =======================================================
  // 메시지
  // =======================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // =======================================================
  // HOME UI
  // =======================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Reader'),

        actions: [
          IconButton(
            tooltip: 'PDF 추가',
            onPressed: _isPicking ? null : _pickPdf,
            icon: const Icon(Icons.add),
          ),
        ],
      ),

      floatingActionButton: _pdfList.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _isPicking ? null : _pickPdf,

              icon: const Icon(Icons.add),

              label: const Text('PDF 추가'),
            ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pdfList.isEmpty
          ? _buildEmptyView()
          : _buildPdfList(),
    );
  }

  // =======================================================
  // PDF가 없을 때
  // =======================================================

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          const Icon(Icons.picture_as_pdf, size: 100, color: Colors.white70),

          const SizedBox(height: 30),

          const Text(
            'PDF Reader',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          const Text(
            '읽을 PDF를 추가하세요.',
            style: TextStyle(fontSize: 16, color: Colors.white60),
          ),

          const SizedBox(height: 40),

          FilledButton.icon(
            onPressed: _isPicking ? null : _pickPdf,

            icon: const Icon(Icons.folder_open),

            label: const Text('PDF 추가'),
          ),
        ],
      ),
    );
  }

  // =======================================================
  // PDF 목록
  // =======================================================

  Widget _buildPdfList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),

      itemCount: _pdfList.length,

      separatorBuilder: (_, __) => const Divider(),

      itemBuilder: (context, index) {
        final item = _pdfList[index];

        final currentPage = item.lastPage + 1;

        String pageText;

        if (item.totalPages > 0) {
          pageText = '$currentPage / ${item.totalPages} 페이지';
        } else {
          pageText = '$currentPage 페이지';
        }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),

          leading: const SizedBox(
            width: 55,
            height: 55,

            child: Icon(Icons.picture_as_pdf, size: 42),
          ),

          title: Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,

            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),

          subtitle: Padding(
            padding: const EdgeInsets.only(top: 7),

            child: Text(
              '$pageText'
              '  ·  '
              '북마크 ${item.bookmarks.length}개',
            ),
          ),

          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                _deletePdf(item);
              }
            },

            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline),
                    SizedBox(width: 10),
                    Text('삭제'),
                  ],
                ),
              ),
            ],
          ),

          onTap: () {
            _openPdf(item);
          },
        );
      },
    );
  }
}

// =========================================================
// PDF VIEWER
// =========================================================

class PdfViewerScreen extends StatefulWidget {
  final PdfItem item;

  final Future<void> Function() onChanged;

  const PdfViewerScreen({
    super.key,
    required this.item,
    required this.onChanged,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final Completer<PDFViewController> _controller =
      Completer<PDFViewController>();

  int _currentPage = 0;
  int _totalPages = 0;

  bool _isReady = false;
  bool _showUi = true;

  String? _error;

  @override
  void initState() {
    super.initState();

    _currentPage = widget.item.lastPage;
  }

  // =======================================================
  // 북마크 여부
  // =======================================================

  bool get _isBookmarked {
    return widget.item.bookmarks.contains(_currentPage);
  }

  // =======================================================
  // 북마크 추가 / 삭제
  // =======================================================

  Future<void> _toggleBookmark() async {
    if (_isBookmarked) {
      widget.item.bookmarks.remove(_currentPage);
    } else {
      widget.item.bookmarks.add(_currentPage);

      widget.item.bookmarks.sort();
    }

    await widget.onChanged();

    if (mounted) {
      setState(() {});
    }
  }

  // =======================================================
  // 북마크 목록
  // =======================================================

  Future<void> _showBookmarks() async {
    final bookmarks = List<int>.from(widget.item.bookmarks);

    bookmarks.sort();

    await showModalBottomSheet(
      context: context,

      showDragHandle: true,

      builder: (context) {
        if (bookmarks.isEmpty) {
          return const SizedBox(
            height: 200,

            child: Center(
              child: Text('저장된 북마크가 없습니다.', style: TextStyle(fontSize: 17)),
            ),
          );
        }

        return SafeArea(
          child: ListView(
            shrinkWrap: true,

            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 5, 20, 15),

                child: Text(
                  '북마크',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),

              ...bookmarks.map((page) {
                return ListTile(
                  leading: const Icon(Icons.bookmark),

                  title: Text('${page + 1} 페이지'),

                  trailing: const Icon(Icons.chevron_right),

                  onTap: () async {
                    Navigator.pop(context);

                    final controller = await _controller.future;

                    await controller.setPage(page);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // =======================================================
  // 이전 페이지
  // =======================================================

  Future<void> _previousPage() async {
    if (_currentPage <= 0) {
      return;
    }

    final controller = await _controller.future;

    await controller.setPage(_currentPage - 1);
  }

  // =======================================================
  // 다음 페이지
  // =======================================================

  Future<void> _nextPage() async {
    if (_currentPage >= _totalPages - 1) {
      return;
    }

    final controller = await _controller.future;

    await controller.setPage(_currentPage + 1);
  }

  // =======================================================
  // UI 표시/숨김
  // =======================================================

  void _toggleUi() {
    setState(() {
      _showUi = !_showUi;
    });
  }

  // =======================================================
  // 페이지 저장
  // =======================================================

  Future<void> _saveCurrentPage(int page, int total) async {
    widget.item.lastPage = page;

    widget.item.totalPages = total;

    widget.item.lastOpenedAt = DateTime.now().millisecondsSinceEpoch;

    await widget.onChanged();
  }

  // =======================================================
  // PDF VIEW
  // =======================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      body: Stack(
        children: [
          // =================================================
          // PDF
          // =================================================
          Positioned.fill(
            child: PDFView(
              filePath: widget.item.path,

              enableSwipe: true,

              swipeHorizontal: true,

              autoSpacing: false,

              pageFling: true,

              pageSnap: true,

              fitPolicy: FitPolicy.BOTH,

              minZoom: 1.0,

              maxZoom: 5.0,

              backgroundColor: Colors.black,

              // ★ 마지막 읽은 페이지
              defaultPage: widget.item.lastPage,

              onViewCreated: (PDFViewController controller) {
                if (!_controller.isCompleted) {
                  _controller.complete(controller);
                }
              },

              onRender: (int? pages) {
                if (!mounted) {
                  return;
                }

                final total = pages ?? 0;

                // 저장된 페이지가
                // PDF 페이지 수보다 큰 경우 방지
                if (total > 0 && _currentPage >= total) {
                  _currentPage = total - 1;
                }

                setState(() {
                  _totalPages = total;

                  _isReady = true;
                });
              },

              onPageChanged: (int? page, int? total) {
                if (!mounted) {
                  return;
                }

                final newPage = page ?? 0;

                final newTotal = total ?? _totalPages;

                setState(() {
                  _currentPage = newPage;

                  _totalPages = newTotal;
                });

                // ★ 현재 페이지 자동 저장
                _saveCurrentPage(newPage, newTotal);
              },

              onError: (error) {
                if (!mounted) {
                  return;
                }

                setState(() {
                  _error = error.toString();
                });
              },
            ),
          ),

          // =================================================
          // 중앙 터치
          // UI 표시/숨김
          // =================================================
          Positioned(
            top: 100,
            bottom: 100,

            left: MediaQuery.of(context).size.width * 0.30,

            right: MediaQuery.of(context).size.width * 0.30,

            child: GestureDetector(
              behavior: HitTestBehavior.translucent,

              onTap: _toggleUi,
            ),
          ),

          // =================================================
          // 왼쪽 이동
          // =================================================
          if (_showUi)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,

              width: 80,

              child: SafeArea(
                child: Center(
                  child: IconButton(
                    iconSize: 45,

                    onPressed: _currentPage > 0 ? _previousPage : null,

                    icon: const Icon(Icons.chevron_left),
                  ),
                ),
              ),
            ),

          // =================================================
          // 오른쪽 이동
          // =================================================
          if (_showUi)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,

              width: 80,

              child: SafeArea(
                child: Center(
                  child: IconButton(
                    iconSize: 45,

                    onPressed: _currentPage < _totalPages - 1
                        ? _nextPage
                        : null,

                    icon: const Icon(Icons.chevron_right),
                  ),
                ),
              ),
            ),

          // =================================================
          // 상단 메뉴
          // =================================================
          if (_showUi)
            Positioned(
              left: 0,
              right: 0,
              top: 0,

              child: SafeArea(
                child: Container(
                  height: 64,

                  padding: const EdgeInsets.symmetric(horizontal: 10),

                  color: Colors.black.withValues(alpha: 0.75),

                  child: Row(
                    children: [
                      // 뒤로
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },

                        icon: const Icon(Icons.arrow_back),
                      ),

                      const SizedBox(width: 10),

                      // 파일명
                      Expanded(
                        child: Text(
                          widget.item.name,

                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,

                          style: const TextStyle(fontSize: 17),
                        ),
                      ),

                      // -------------------------------------
                      // 북마크 목록
                      // -------------------------------------
                      IconButton(
                        tooltip: '북마크 목록',

                        onPressed: _showBookmarks,

                        icon: const Icon(Icons.bookmarks_outlined),
                      ),

                      // -------------------------------------
                      // 현재 페이지 북마크
                      // -------------------------------------
                      IconButton(
                        tooltip: _isBookmarked ? '북마크 삭제' : '북마크 추가',

                        onPressed: _toggleBookmark,

                        icon: Icon(
                          _isBookmarked
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // =================================================
          // 페이지 번호
          // =================================================
          if (_showUi && _totalPages > 0)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,

              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),

                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),

                    borderRadius: BorderRadius.circular(20),
                  ),

                  child: Row(
                    mainAxisSize: MainAxisSize.min,

                    children: [
                      if (_isBookmarked) ...[
                        const Icon(Icons.bookmark, size: 17),

                        const SizedBox(width: 5),
                      ],

                      Text(
                        '${_currentPage + 1} / $_totalPages',

                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // =================================================
          // 로딩
          // =================================================
          if (!_isReady && _error == null)
            const Center(child: CircularProgressIndicator()),

          // =================================================
          // 오류
          // =================================================
          if (_error != null)
            Center(
              child: Container(
                margin: const EdgeInsets.all(40),

                padding: const EdgeInsets.all(24),

                decoration: BoxDecoration(
                  color: Colors.red.shade900,

                  borderRadius: BorderRadius.circular(15),
                ),

                child: Text(
                  'PDF를 열 수 없습니다.\n\n$_error',

                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
