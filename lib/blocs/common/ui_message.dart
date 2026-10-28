import 'package:equatable/equatable.dart';

/// A friendly one-time message for a snack bar. The [tick] changes every
/// time, so the same text can be shown twice.
class UiMessage extends Equatable {
  final String text;
  final bool isError;
  final int tick;
  const UiMessage(this.text, {this.isError = false, this.tick = 0});

  @override
  List<Object?> get props => [text, isError, tick];
}
