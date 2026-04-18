import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/trans/contracts_language.dart';
import '../../../core/trans/language_provider.dart';
import 'package:provider/provider.dart';

/// In-app PDF viewer (loads bytes via HTTP; optional auth headers).
class ContractPdfViewerScreen extends StatefulWidget {
  const ContractPdfViewerScreen({
    super.key,
    required this.pdfUrl,
    required this.title,
    this.httpHeaders,
  });

  final String pdfUrl;
  final String title;
  final Map<String, String>? httpHeaders;

  @override
  State<ContractPdfViewerScreen> createState() => _ContractPdfViewerScreenState();
}

class _ContractPdfViewerScreenState extends State<ContractPdfViewerScreen> {
  late final PdfControllerPinch _controller;

  @override
  void initState() {
    super.initState();
    _controller = PdfControllerPinch(
      document: PdfDocument.openData(_fetchPdf()),
      initialPage: 1,
    );
  }

  Future<Uint8List> _fetchPdf() async {
    final res = await http.get(
      Uri.parse(widget.pdfUrl),
      headers: widget.httpHeaders,
    );
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }
    return res.bodyBytes;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context).language;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : const Color(0xFFF0F4FF);
    final fg = isDark ? AppColors.darkText : AppColors.lightText;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        foregroundColor: fg,
        elevation: 0,
        title: Text(
          widget.title,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: fg),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.chevron_left_rounded, color: fg),
            onPressed: () => _controller.previousPage(
              curve: Curves.easeOut,
              duration: const Duration(milliseconds: 200),
            ),
          ),
          PdfPageNumber(
            controller: _controller,
            builder: (_, loadingState, page, pagesCount) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  loadingState == PdfLoadingState.success
                      ? '$page / ${pagesCount ?? 0}'
                      : '…',
                  style: TextStyle(fontSize: 14, color: fg),
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right_rounded, color: fg),
            onPressed: () => _controller.nextPage(
              curve: Curves.easeOut,
              duration: const Duration(milliseconds: 200),
            ),
          ),
        ],
      ),
      body: PdfViewPinch(
        controller: _controller,
        builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
          options: const DefaultBuilderOptions(),
          documentLoaderBuilder: (_) => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          pageLoaderBuilder: (_) => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          errorBuilder: (_, error) => Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                '${ContractsLanguage.get('open_pdf_error', lang)}\n$error',
                textAlign: TextAlign.center,
                style: TextStyle(color: fg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
