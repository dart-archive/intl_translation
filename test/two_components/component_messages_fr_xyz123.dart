// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a fr_xyz123 locale. All the
// messages from the main program should be duplicated here with the same
// function name.

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = MessageLookup();

// ignore: unused_element
final _keepAnalysisHappy = Intl.defaultLocale;

// ignore: non_constant_identifier_names
typedef MessageIfAbsent = Function(String message_str, List args);

class MessageLookup extends MessageLookupByLibrary {
  @override
  String get localeName => 'fr_xyz123';

  @override
  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, String Function()> _notInlinedMessages(_) => {
        'Hello from component':
            MessageLookupByLibrary.simpleMessage('Bonjour du composant'),
        '_message2': MessageLookupByLibrary.simpleMessage('Locale explicite')
      };
}
