import 'package:cp_core/src/failure.dart';
import 'package:meta/meta.dart';

/// Explicit success/failure carrier so that command results crossing the
/// app/backend boundary are handled rather than thrown past a UI layer.
@immutable
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;
  const factory Result.err(Failure failure) = Err<T>;

  bool get isOk => this is Ok<T>;

  /// Exhaustive handling; the analyzer flags a missing branch.
  R fold<R>(R Function(T value) onOk, R Function(Failure failure) onErr) =>
      switch (this) {
        final Ok<T> r => onOk(r.value),
        final Err<T> r => onErr(r.failure),
      };
}

@immutable
final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;

  @override
  bool operator ==(Object other) => other is Ok<T> && other.value == value;

  @override
  int get hashCode => Object.hash(Ok<T>, value);
}

@immutable
final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;

  @override
  bool operator ==(Object other) => other is Err<T> && other.failure == failure;

  @override
  int get hashCode => Object.hash(Err<T>, failure);
}
