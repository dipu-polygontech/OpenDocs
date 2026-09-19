import 'dart:async';

import 'package:openreader/core/domain/error/failure.dart';
import 'package:openreader/core/domain/models/document_category.dart';
import 'package:openreader/core/domain/models/document_model.dart';
import 'package:openreader/core/domain/repositories/document_repository.dart';
import 'package:openreader/core/domain/usecase/usecase.dart';
import 'package:openreader/features/files/presentation/files_controller.dart';
import 'package:openreader/services/utilities/storage_access_service.dart';
import 'package:dartz/dartz.dart';
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
/// simulate a slow earlier response racing a fast later one.
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

class FixtureAccess implements StorageAccessService {
  @override
  Future<bool> hasAccess() async => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('a slow earlier load does not overwrite a faster later one (ODF-P6-05)', () async {
    final docs = FixtureDocuments();
    final controller = FilesController(documentRepository: docs, storageAccess: FixtureAccess());

    // The first call must reach its own getDocuments() (past `await
    // hasAccess()`) before the second one starts, so both are legitimately
    // in flight together - matching the real race (an earlier query still
    // running when a newer one starts), not the request-not-even-sent case
    // the requestId guard already short-circuits before hasAccess resolves.
    final firstLoad = controller.load();
    await Future<void>.delayed(Duration.zero);
    expect(docs.pending.length, 1);

    final secondLoad = controller.load();
    await Future<void>.delayed(Duration.zero);
    expect(docs.pending.length, 2);

    // The second (current) call resolves first.
    docs.pending[1].complete(Right([_doc('current.pdf')]));
    await secondLoad;
    expect(controller.documents, [_doc('current.pdf')]);

    // The first (now-stale) call resolves after - must not overwrite it.
    docs.pending[0].complete(Right([_doc('stale.pdf')]));
    await firstLoad;
    expect(controller.documents, [_doc('current.pdf')]);
  });
}
