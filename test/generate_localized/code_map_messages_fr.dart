// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a fr locale. All the
// messages from the main program should be duplicated here with the same
// function name.

import 'package:intl/message_lookup_by_library.dart';

import 'code_map_messages_all.dart' show evaluateJsonTemplate;

final messages = MessageLookup();

typedef MessageIfAbsent = String Function(String messageStr, List<Object> args);

class MessageLookup extends MessageLookupByLibrary {
  @override
  String get localeName => 'fr';

  @override
  // ignore: type_annotate_public_apis
  String evaluateMessage(translation, List<dynamic> args) {
    return evaluateJsonTemplate(translation, args);
  }

  @override
  Map<String, dynamic> get messages => _constMessages;
  static const _constMessages = <String, Object>{
    'Hello from application': "Bonjour de l'application"
  };
}
