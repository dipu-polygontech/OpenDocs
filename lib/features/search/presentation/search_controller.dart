import 'dart:async';

import 'package:get/get.dart';

import '../../../core/data/repositories/document_repository_impl.dart';
import '../../../core/domain/models/document_model.dart';
import '../../../core/domain/repositories/document_repository.dart';
import '../../../core/presentation/controllers/base_controller.dart';
import '../../../core/presentation/utils/state_status.dart';

/// File Search screen (BRD 9.7 - case-insensitive, partial-match filename search).
class SearchDocumentsController extends BaseController {
  final DocumentRepository _documentRepository;

  SearchDocumentsController({DocumentRepository? documentRepository})
      : _documentRepository = documentRepository ?? DocumentRepositoryImpl();

  final results = <DocumentModel>[].obs;
  final query = ''.obs;

  Timer? _debounce;

  // ODF-P6-05: debouncing the 250ms trigger doesn't order the responses - if
  // an earlier search is slow enough that a second one fires and resolves
  // first, whichever DB read finishes last previously won regardless of
  // which term is actually current. Only the most recently started search's
  // result is ever applied.
  int _searchRequestId = 0;

  void onQueryChanged(String value) {
    query.value = value;
    _debounce?.cancel();

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      results.clear();
      status.value = StateStatus.initial;
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 250), () => _search(trimmed));
  }

  void clear() {
    query.value = '';
    results.clear();
    status.value = StateStatus.initial;
    _debounce?.cancel();
  }

  Future<void> _search(String term) async {
    final requestId = ++_searchRequestId;
    status.value = StateStatus.loading;
    final result = await _documentRepository.getDocuments(query: term);
    if (requestId != _searchRequestId) return;
    result.fold(
      (failure) => handleFailure(failure),
      (list) {
        results.assignAll(list);
        status.value = list.isEmpty ? StateStatus.empty : StateStatus.success;
      },
    );
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }
}
