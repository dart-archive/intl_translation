// DO NOT EDIT. This file is generated by package:intl_translation.

// This is a library that provides messages for a fr locale. All the messages
// from the main program should be duplicated here with the same function name.

// ignore_for_file: directives_ordering
// ignore_for_file: file_names
// ignore_for_file: invalid_assignment
// ignore_for_file: prefer_single_quotes
// ignore_for_file: unnecessary_brace_in_string_interps
// ignore_for_file: unused_import

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';
import 'dart:convert';

import 'code_map_messages_all.dart' show evaluateJsonTemplate;

import 'dart:collection';

final MessageLookup messages = MessageLookup();


class MessageLookup extends MessageLookupByLibrary {
  @override
  String get localeName => 'fr';


  @override
  String? evaluateMessage(dynamic translation, List<dynamic> args) {
    return evaluateJsonTemplate(translation, args);
  }
  @override
  Map<String, dynamic> get messages => _constMessages;

  static const _constMessages = <String, Object?>{"Hello from application":<Object?>["Bonjour de l'application"]};

}