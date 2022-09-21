import 'package:intl_translation/src/messages/message.dart';

/// Represents a simple constant string with no dynamic elements.
class LiteralString extends Message {
  String string;
  LiteralString(this.string, [Message? parent]) : super(parent);
  @override
  String toCode() => Message.escapeString(string);
  @override
  String toJson() => string;
  @override
  String toString() => 'Literal($string)';
  @override
  String expanded(
          [String Function(dynamic, dynamic) transform = nullTransform]) =>
      transform(this, string);
}
