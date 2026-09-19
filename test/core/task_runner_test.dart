import 'package:openreader/core/domain/error/failure.dart';
import 'package:openreader/core/presentation/utils/task_runner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

/// sqflite's own DatabaseException implementations (SqfliteDatabaseException)
/// aren't exported publicly - this minimal fake is enough to exercise the
/// `is DatabaseException` branch in task_runner.dart.
class _FakeDatabaseException extends DatabaseException {
  _FakeDatabaseException(String message) : super(message);
  @override
  int? getResultCode() => null;
  @override
  Object? get result => null;
}

/// ODF-P6-06/12: this file previously had zero test coverage.
void main() {
  test('returns Right on success', () async {
    final result = await runTask(() async => 42);
    expect(result.isRight(), isTrue);
    result.fold((_) => fail('expected Right'), (value) => expect(value, 42));
  });

  test('maps a DatabaseException to LocalDatabaseQueryFailure, not ServerFailure', () async {
    final result = await runTask<int>(() async {
      throw _FakeDatabaseException('disk full');
    });
    expect(result.isLeft(), isTrue);
    result.fold((failure) => expect(failure, isA<LocalDatabaseQueryFailure>()), (_) => fail('expected Left'));
  });

  test('maps a non-database exception to ServerFailure, unchanged', () async {
    final result = await runTask<int>(() async {
      throw Exception('something else');
    });
    expect(result.isLeft(), isTrue);
    result.fold((failure) => expect(failure, isA<ServerFailure>()), (_) => fail('expected Left'));
  });
}
