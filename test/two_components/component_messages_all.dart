// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that looks up messages for specific locales by
// delegating to the appropriate library.

import 'dart:async';

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';
import 'package:intl/src/intl_helpers.dart';

import 'component_messages_fr_xyz123.dart' deferred as messages_fr_xyz123;

typedef Future<dynamic> LibraryLoader();
Map<String, LibraryLoader> _deferredLibraries = {
  'fr_xyz123': () => messages_fr_xyz123.loadLibrary(),
};

MessageLookupByLibrary _findExact(localeName) {
  switch (localeName) {
    case 'fr_xyz123':
      return messages_fr_xyz123.messages;
    default:
      return null;
  }
}

/// User programs should call this before using [localeName] for messages.
Future initializeMessages(String localeName) {
  var lib = _deferredLibraries[Intl.canonicalizedLocale(localeName)];
  var load = lib == null ? new Future.value(false) : lib();
  return load.then((_) {
    initializeInternalMessageLookup(() => new CompositeMessageLookup());
    messageLookup.addLocale(localeName, _findGeneratedMessagesFor);
  });
}

bool _messagesExistFor(String locale) {
  var messages;
  try {
    messages = _findExact(locale);
  } catch (e) {}
  return messages != null;
}

MessageLookupByLibrary _findGeneratedMessagesFor(locale) {
  var actualLocale =
      Intl.verifiedLocale(locale, _messagesExistFor, onFailure: (_) => null);
  if (actualLocale == null) return null;
  return _findExact(actualLocale);
}
