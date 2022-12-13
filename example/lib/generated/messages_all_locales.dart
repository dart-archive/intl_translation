// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that looks up messages for specific locales by
// delegating to the appropriate library.

// Ignore issues from any lints in this file.
// ignore_for_file: type=lint, unused_import

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';
import 'package:intl/src/intl_helpers.dart';

import 'messages_de_CH.dart' deferred as messages_de_ch;
import 'messages_de.dart' deferred as messages_de;
import 'messages_en.dart' deferred as messages_en;
import 'messages_es.dart' deferred as messages_es;

typedef Future<dynamic> LibraryLoader();
Map<String, LibraryLoader> _deferredLibraries = {
  'de_CH': messages_de_ch.loadLibrary,
  'de': messages_de.loadLibrary,
  'en': messages_en.loadLibrary,
  'es': messages_es.loadLibrary,
};

MessageLookupByLibrary? _findExact(String localeName) {
  switch (localeName) {
    case 'de_CH':
      return messages_de_ch.messages;
    case 'de':
      return messages_de.messages;
    case 'en':
      return messages_en.messages;
    case 'es':
      return messages_es.messages;
    default:
      return null;
  }
}

/// User programs should call this before using [localeName] for messages.
Future<bool> initializeMessages(String? localeName) async {
  var availableLocale = Intl.verifiedLocale(
    localeName,
    (locale) => _deferredLibraries[locale] != null,
    onFailure: (_) => null);
  if (availableLocale == null) {
    return Future.value(false);
  }
  var lib = _deferredLibraries[availableLocale];
  await (lib == null ? Future.value(false) : lib());
  initializeInternalMessageLookup(() => CompositeMessageLookup());
  messageLookup.addLocale(availableLocale, _findGeneratedMessagesFor);
  return Future.value(true);
}

bool _messagesExistFor(String locale) {
  try {
    return _findExact(locale) != null;
  } catch (e) {
    return false;
  }
}

MessageLookupByLibrary? _findGeneratedMessagesFor(String locale) {
  var actualLocale = Intl.verifiedLocale(locale, _messagesExistFor,
      onFailure: (_) => null);
  if (actualLocale == null) return null;
  return _findExact(actualLocale);
}
