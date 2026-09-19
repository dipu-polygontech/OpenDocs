import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/widgets/loading_view/loading_view.dart';
import 'pdf_reader_controller.dart';

/// BRD §9.10 PDF Reader Screen.
class PdfReaderView extends GetView<PdfReaderController> {
  const PdfReaderView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _ReaderAppBar(controller: controller),
      body: Obx(() {
        if (controller.status.value.isBusy) return const LoadingView();
        return Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Obx(() => _buildViewer(context)),
                  Obx(() => controller.showThumbnails.value
                      ? Align(alignment: Alignment.bottomCenter, child: _ThumbnailStrip(controller: controller))
                      : const SizedBox.shrink()),
                ],
              ),
            ),
            _BottomBar(controller: controller),
          ],
        );
      }),
    );
  }

  Widget _buildViewer(BuildContext context) {
    final searcher = controller.textSearcher.value;
    return PdfViewer.file(
      controller.document.path,
      controller: controller.pdfController,
      initialPageNumber: controller.initialPageNumber,
      passwordProvider: controller.providePassword,
      params: PdfViewerParams(
        onViewerReady: controller.onViewerReady,
        onPageChanged: controller.onPageChanged,
        pagePaintCallbacks: searcher == null ? null : [searcher.pageTextMatchPaintCallback],
        layoutPages: controller.viewMode.value == PdfReaderViewMode.horizontal ? _horizontalLayout : null,
        errorBannerBuilder: (context, error, stackTrace, documentRef) => _ReaderErrorView(controller: controller, error: error),
      ),
    );
  }

  static PdfPageLayout _horizontalLayout(List<PdfPage> pages, PdfViewerParams params) {
    final height = pages.fold(0.0, (prev, page) => max(prev, page.height)) + params.margin * 2;
    final pageLayouts = <Rect>[];
    var x = params.margin;
    for (final page in pages) {
      pageLayouts.add(Rect.fromLTWH(x, (height - page.height) / 2, page.width, page.height));
      x += page.width + params.margin;
    }
    return PdfPageLayout(pageLayouts: pageLayouts, documentSize: Size(x, height));
  }
}

class _ReaderAppBar extends StatelessWidget implements PreferredSizeWidget {
  final PdfReaderController controller;

  const _ReaderAppBar({required this.controller});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 40);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Obx(
        () => controller.isSearching.value
            ? TextField(
                autofocus: true,
                style: context.titleMedium,
                decoration: const InputDecoration(hintText: 'Search in document', border: InputBorder.none),
                onChanged: controller.onSearchQueryChanged,
              )
            : Text(controller.document.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      actions: [
        Obx(
          () => controller.isSearching.value
              ? IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close search',
                  onPressed: controller.stopSearching,
                )
              : IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Search in document',
                  // Text search needs a live document (see textSearcher's doc
                  // comment); disabled until onViewerReady supplies one.
                  onPressed: controller.textSearcher.value != null ? controller.startSearching : null,
                ),
        ),
        Obx(
          () => IconButton(
            icon: Icon(controller.isFavorite ? Icons.favorite : Icons.favorite_border),
            tooltip: controller.isFavorite ? 'Remove from favorites' : 'Add to favorites',
            onPressed: controller.toggleFavorite,
          ),
        ),
        PopupMenuButton<_ReaderAction>(
          tooltip: 'More options',
          onSelected: (action) => _handle(action),
          itemBuilder: (context) => const [
            PopupMenuItem(value: _ReaderAction.share, child: Text('Share')),
            PopupMenuItem(value: _ReaderAction.openWith, child: Text('Open With')),
            PopupMenuItem(value: _ReaderAction.toggleViewMode, child: Text('Toggle View Mode')),
            PopupMenuItem(value: _ReaderAction.toggleThumbnails, child: Text('Thumbnails')),
          ],
        ),
      ],
      bottom: PreferredSize(preferredSize: const Size.fromHeight(40), child: _SearchStatusBar(controller: controller)),
    );
  }

  void _handle(_ReaderAction action) {
    switch (action) {
      case _ReaderAction.share:
        controller.share();
      case _ReaderAction.openWith:
        controller.openWith();
      case _ReaderAction.toggleViewMode:
        controller.toggleViewMode();
      case _ReaderAction.toggleThumbnails:
        controller.toggleThumbnails();
    }
  }
}

enum _ReaderAction { share, openWith, toggleViewMode, toggleThumbnails }

class _SearchStatusBar extends StatelessWidget {
  final PdfReaderController controller;

  const _SearchStatusBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.isSearching.value) return const SizedBox.shrink();
      final searcher = controller.textSearcher.value;
      if (searcher == null) return const SizedBox.shrink();
      return ListenableBuilder(
        listenable: searcher,
        builder: (context, _) {
          final String label;
          if (searcher.pattern == null) {
            label = '';
          } else if (searcher.isSearching) {
            label = 'Searching…';
          } else if (searcher.matches.isEmpty) {
            // BRD §13.
            label = 'No searchable text found.';
          } else {
            label = '${(searcher.currentIndex ?? 0) + 1} of ${searcher.matches.length} result(s)';
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text(label, style: context.bodySmall)),
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_up),
                  tooltip: 'Previous match',
                  onPressed: searcher.hasMatches ? controller.goToPrevMatch : null,
                ),
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down),
                  tooltip: 'Next match',
                  onPressed: searcher.hasMatches ? controller.goToNextMatch : null,
                ),
              ],
            ),
          );
        },
      );
    });
  }
}

class _BottomBar extends StatelessWidget {
  final PdfReaderController controller;

  const _BottomBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.pageCount.value < 1) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: context.surfaceContainer,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => _showJumpToPageDialog(context),
              child: Text('Page ${controller.currentPage.value} of ${controller.pageCount.value}'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _showJumpToPageDialog(BuildContext context) async {
    final controllerText = TextEditingController(text: controller.currentPage.value.toString());
    // ODF-P6-33: an unparseable/out-of-range page number previously closed
    // the dialog with zero feedback (int.tryParse returned null, the
    // `if (page != null)` guard below just silently did nothing). Disables
    // "Go" instead, with inline error text, until the input is valid.
    final page = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final parsed = int.tryParse(controllerText.text);
          final valid = parsed != null && parsed >= 1 && parsed <= controller.pageCount.value;
          return AlertDialog(
            title: const Text('Jump to page'),
            content: TextField(
              controller: controllerText,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '1–${controller.pageCount.value}',
                errorText: controllerText.text.isNotEmpty && !valid
                    ? 'Enter a page between 1 and ${controller.pageCount.value}'
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              FilledButton(
                onPressed: valid ? () => Navigator.of(context).pop(parsed) : null,
                child: const Text('Go'),
              ),
            ],
          );
        },
      ),
    );
    // ODF-P6-17: the one TextEditingController in the reader surface
    // without a disposal path.
    controllerText.dispose();
    if (page != null) unawaited(controller.jumpToPage(page));
  }
}

class _ThumbnailStrip extends StatelessWidget {
  final PdfReaderController controller;

  const _ThumbnailStrip({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      color: context.surface.withValues(alpha: 0.95),
      child: PdfDocumentViewBuilder(
        documentRef: controller.pdfController.documentRef,
        builder: (context, document) => ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(8),
          itemCount: document?.pages.length ?? 0,
          itemBuilder: (context, index) {
            final pageNumber = index + 1;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Obx(
                () => Semantics(
                  button: true,
                  label: 'Page $pageNumber',
                  selected: controller.currentPage.value == pageNumber,
                  child: GestureDetector(
                    onTap: () => controller.jumpToPage(pageNumber),
                    child: ExcludeSemantics(
                      child: Container(
                        width: 70,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: controller.currentPage.value == pageNumber ? context.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(child: PdfPageView(document: document, pageNumber: pageNumber, maximumDpi: 50)),
                            Text('$pageNumber', style: context.labelSmall),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ReaderErrorView extends StatelessWidget {
  final PdfReaderController controller;
  final Object error;

  const _ReaderErrorView({required this.controller, required this.error});

  @override
  Widget build(BuildContext context) {
    // BRD §13: password failures are handled entirely by the password
    // dialog retry loop (PdfReaderController.providePassword); reaching
    // here with a PdfPasswordException means the user already cancelled and
    // left, so this always shows the generic corrupted/unsupported message.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 16),
            const Text('This document may be damaged or incomplete.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(onPressed: () => Get.back(), child: const Text('Close')),
                const SizedBox(width: 8),
                FilledButton(onPressed: controller.openWith, child: const Text('Try another app')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
