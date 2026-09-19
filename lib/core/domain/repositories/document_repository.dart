import '../models/document_category.dart';
import '../models/document_model.dart';
import '../usecase/usecase.dart';

abstract class DocumentRepository {
  /// Re-scans local storage, persists the result, and returns the refreshed
  /// index (BRD 7.1 - Local Document Discovery). Files no longer found are
  /// dropped from the index but never touched on disk.
  ResultFuture<List<DocumentModel>> rescan();

  /// Inserts or updates a single document (BRD §7.7 "Open From Other Apps" -
  /// indexing a file another app hands to OpenReader via an incoming intent).
  /// Unlike [rescan], this never removes any other row.
  ResultFuture<DocumentModel> indexDocument(DocumentModel document);

  /// Looks up an already-indexed document with the same display name and
  /// size (case-insensitive name match), or `null` if none exists.
  ///
  /// ODF-P6-01: used before indexing an incoming shared-in file, so a file
  /// already in the index that's re-shared back into OpenReader (Android
  /// copies shared content into an app-private cache path first) resolves
  /// to its original, scan-rooted row instead of creating a second row at
  /// the ephemeral cache path - which [rescan] would otherwise delete on
  /// the next refresh, cascading into a silent loss of that file's
  /// favorite/recent status.
  ResultFuture<DocumentModel?> findByFingerprint({
    required String displayName,
    required int sizeBytes,
  });

  ResultFuture<List<DocumentModel>> getDocuments({
    DocumentCategory? category,
    String? query,
    DocumentSortMode sort = DocumentSortMode.nameAsc,
  });

  ResultFuture<DocumentModel?> getById(String id);

  ResultFuture<int> countByCategory(DocumentCategory category);
}
