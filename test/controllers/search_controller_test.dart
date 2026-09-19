import 'dart:async';

import 'package:openreader/core/domain/error/failure.dart';
import 'package:openreader/core/domain/models/document_category.dart';
import 'package:openreader/core/domain/models/document_model.dart';
import 'package:openreader/core/domain/repositories/document_repository.dart';
import 'package:openreader/core/domain/usecase/usecase.dart';
import 'package:openreader/features/search/presentation/search_controller.dart';
import 'package:dartz/dartz.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

DocumentModel _doc(String name) => DocumentModel(
      id: '/fixtures/$name',
      path: '/fixtures/$name',
      displayName: name,
      extension: 'pdf',
      category: DocumentCategory.pdf,
      sizeBytes: 1,
      modifiedAt: DateTime(2026),
      lastSeenAt: DateTime(2026),
    );

/// Each call to getDocuments() returns its own controllable Completer,
/// appended in call order, so a test can resolve calls out of order to
/// simulate a slow earlier search racing a fast later one.
class FixtureDocuments implements DocumentRepository {
  final List<Completer<Either<Failure, List<DocumentModel>>>> pending = [];

  @override
  ResultFuture<List<DocumentModel>> getDocuments({
    DocumentCategory? category,
    String? query,
    DocumentSortMode sort = DocumentSortMode.nameAsc,
  }) {
    final completer = Completer<Either<Failure, List<DocumentModel>>>();
    pending.add(completer);
    return completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('a slow earlier search does not overwrite a faster later one (ODF-P6-05)', () {
    fakeAsync((async) {
      final docs = FixtureDocuments();
      final controller = SearchDocumentsController(documentRepository: docs);

      controller.onQueryChanged('slow');
      async.elapse(const Duration(milliseconds: 250));
      controller.onQueryChanged('fast');
      async.elapse(const Duration(milliseconds: 250));
      expect(docs.pending.length, 2);

      // The second (current) search resolves first.
      docs.pending[1].complete(Right([_doc('fast-result.pdf')]));
      async.flushMicrotasks();
      expect(controller.results, [_doc('fast-result.pdf')]);

      // The first (now-stale) search resolves after - must not overwrite it.
      docs.pending[0].complete(Right([_doc('slow-result.pdf')]));
      async.flushMicrotasks();
      expect(controller.results, [_doc('fast-result.pdf')]);
    });
  });
}
