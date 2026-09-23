import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const PdfReaderApp());
}

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
// Home
// =========================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isPicking = false;

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

      if (result == null) {
        return;
      }

      if (result.files.isEmpty) {
        return;
      }

      final file = result.files.first;

      final path = file.path;

      if (path == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('PDF 파일 경로를 가져올 수 없습니다.')));

        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(filePath: path, fileName: file.name),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF 선택 중 오류가 발생했습니다.\n$e')));
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
        });
      }
    }
  }

  // =======================================================
  // UI
  // =======================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              const Icon(
                Icons.picture_as_pdf,
                size: 100,
                color: Colors.white70,
              ),

              const SizedBox(height: 30),

              const Text(
                'PDF Reader',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              const Text(
                'iPad의 파일 앱에서 PDF를 선택하세요.',
                style: TextStyle(fontSize: 16, color: Colors.white60),
              ),

              const SizedBox(height: 40),

              FilledButton.icon(
                onPressed: _isPicking ? null : _pickPdf,

                icon: _isPicking
                    ? const SizedBox(
                        width: 20,
                        height: 20,

                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.folder_open),

                label: Text(_isPicking ? '파일 선택 중...' : 'PDF 열기'),

                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 20,
                  ),

                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================
// PDF Viewer
// =========================================================

class PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const PdfViewerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
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
  // UI 표시 / 숨김
  // =======================================================

  void _toggleUi() {
    setState(() {
      _showUi = !_showUi;
    });
  }

  // =======================================================
  // Viewer
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
              filePath: widget.filePath,

              // 페이지 이동 가능
              enableSwipe: true,

              // Kindle 같은 좌우 페이지 이동
              swipeHorizontal: true,

              // 페이지 사이의 여백 제거
              autoSpacing: false,

              // 한 페이지씩 넘김
              pageFling: true,

              pageSnap: true,

              // 가로/세로 모두 화면에 맞춤
              fitPolicy: FitPolicy.BOTH,

              // 최대 확대
              minZoom: 1.0,

              maxZoom: 5.0,

              backgroundColor: Colors.black,

              defaultPage: 0,

              onViewCreated: (PDFViewController controller) {
                if (!_controller.isCompleted) {
                  _controller.complete(controller);
                }
              },

              onRender: (int? pages) {
                if (!mounted) {
                  return;
                }

                setState(() {
                  _totalPages = pages ?? 0;

                  _isReady = true;
                });
              },

              onPageChanged: (int? page, int? total) {
                if (!mounted) {
                  return;
                }

                setState(() {
                  _currentPage = page ?? 0;

                  _totalPages = total ?? _totalPages;
                });
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
          // 터치 영역
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
          // 이전 페이지 터치 영역
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
          // 다음 페이지 터치 영역
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
          // 상단 UI
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
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },

                        icon: const Icon(Icons.arrow_back),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Text(
                          widget.fileName,

                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,

                          style: const TextStyle(fontSize: 17),
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

                  child: Text(
                    '${_currentPage + 1} / $_totalPages',

                    style: const TextStyle(fontSize: 16),
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
