// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// This provides utilities for generating localized versions of
/// messages. It does not stand alone, but expects to be given
/// TranslatedMessage objects and generate code for a particular locale
/// based on them.
///
/// An example of usage can be found
/// in test/message_extract/generate_from_json.dart
library generate_localized;

import 'package:intl/intl.dart';
import 'src/intl_message.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

class MessageGeneration {
  /// If the import path following package: is something else, modify the
  /// [intlImportPath] variable to change the import directives in the generated
  /// code.
  var intlImportPath = 'intl';

  /// If the path to the generated files is something other than the current
  /// directory, update the [generatedImportPath] variable to change the import
  /// directives in the generated code.
  var generatedImportPath = '';

  /// Given a base file, return the file prefixed with the path to import it.
  /// By default, that is in the current directory, but if [generatedImportPath]
  /// has been set, then use that as a prefix.
  String importForGeneratedFile(String file) =>
      generatedImportPath.isEmpty ? file : "$generatedImportPath/$file";

  /// A list of all the locales for which we have translations. Code that does
  /// the reading of translations should add to this.
  List<String> allLocales = [];

  /// If we have more than one set of messages to generate in a particular
  /// directory we may want to prefix some to distinguish them.
  String generatedFilePrefix = '';

  /// Should we use deferred loading for the generated libraries.
  bool useDeferredLoading = true;

  /// The mode to generate in - either 'release' or 'debug'.
  ///
  /// In release mode, a missing translation is an error. In debug mode, it
  /// falls back to the original string.
  String codegenMode;

  get releaseMode => codegenMode == 'release';

  bool get jsonMode => false;

  /// Holds the generated translations.
  StringBuffer output = new StringBuffer();

  void clearOutput() {
    output = new StringBuffer();
  }

  /// Generate a file <[generated_file_prefix]>_messages_<[locale]>.dart
  /// for the [translations] in [locale] and put it in [targetDir].
  void generateIndividualMessageFile(String basicLocale,
      Iterable<TranslatedMessage> translations, String targetDir) {
    clearOutput();
    var locale = new MainMessage()
        .escapeAndValidateString(Intl.canonicalizedLocale(basicLocale));
    output.write(prologue(locale));
    // Exclude messages with no translation and translations with no matching
    // original message (e.g. if we're using some messages from a larger catalog)
    var usableTranslations = translations
        .where((each) => each.originalMessages != null && each.message != null)
        .toList();
    for (var each in usableTranslations) {
      for (var original in each.originalMessages) {
        original.addTranslation(locale, each.message);
      }
    }
    usableTranslations.sort((a, b) =>
        a.originalMessages.first.name.compareTo(b.originalMessages.first.name));

    writeTranslations(usableTranslations, locale);

    // To preserve compatibility, we don't use the canonical version of the
    // locale in the file name.
    var filename = path.join(
        targetDir, "${generatedFilePrefix}messages_$basicLocale.dart");
    new File(filename).writeAsStringSync(output.toString());
  }

  /// Write out the translated forms.
  void writeTranslations(
      Iterable<TranslatedMessage> usableTranslations, String locale) {
    for (var translation in usableTranslations) {
      // Some messages we generate as methods in this class. Simpler ones
      // we inline in the map from names to messages.
      var messagesThatNeedMethods =
          translation.originalMessages.where((each) => _hasArguments(each));
      for (var original in messagesThatNeedMethods) {
        output
          ..write("  ")
          ..write(
              original.toCodeForLocale(locale, _methodNameFor(original.name)))
          ..write("\n\n");
      }
    }
    output.write(messagesDeclaration);

    // Now write the map of names to either the direct translation or to a
    // method.
    var entries = usableTranslations
        .expand((translation) => translation.originalMessages)
        .map((original) =>
            '    "${original.escapeAndValidateString(original.name)}" '
            ': ${_mapReference(original, locale)}');
    output..write(entries.join(",\n"))..write("\n  };\n}\n");
  }

  /// Any additional imports the individual message files need.
  String get extraImports => '';

  String get messagesDeclaration =>
      // Includes some gyrations to prevent parts of the deferred libraries from
      // being inlined into the main one, defeating the space savings. Issue
      // 24356
      """
  final messages = _notInlinedMessages(_notInlinedMessages);
  static _notInlinedMessages(_) => {
""";

  /// [generateIndividualMessageFile] for the beginning of the file,
  /// parameterized by [locale].
  String prologue(String locale) =>
      """
// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a $locale locale. All the
// messages from the main program should be duplicated here with the same
// function name.

import 'package:$intlImportPath/intl.dart';
import 'package:$intlImportPath/message_lookup_by_library.dart';
$extraImports
final messages = new MessageLookup();

final _keepAnalysisHappy = Intl.defaultLocale;

typedef MessageIfAbsent(String message_str, List args);

class MessageLookup extends MessageLookupByLibrary {
  get localeName => '$locale';

""" +
      (releaseMode ? overrideLookup : "");

  String overrideLookup = """
  String lookupMessage(
      String message_str, String locale, String name, List args, String meaning,
      {MessageIfAbsent ifAbsent}) {
    String failedLookup(String message_str, List args) {
      // If there's no message_str, then we are an internal lookup, e.g. an
      // embedded plural, and shouldn't fail.
      if (message_str == null) return null;
      throw new UnsupportedError(
          "No translation found for message '\$name',\\n"
          "  original text '\$message_str'");
    }
    return super.lookupMessage(message_str, locale, name, args, meaning,
        ifAbsent: ifAbsent ?? failedLookup);
  }

""";

  /// This section generates the messages_all.dart file based on the list of
  /// [allLocales].
  String generateMainImportFile() {
    clearOutput();
    output.write(mainPrologue);
    for (var locale in allLocales) {
      var baseFile = '${generatedFilePrefix}messages_$locale.dart';
      var file = importForGeneratedFile(baseFile);
      output.write("import '$file' ");
      if (useDeferredLoading) output.write("deferred ");
      output.write("as ${_libraryName(locale)};\n");
    }
    output.write("\n");
    output.write("typedef Future<dynamic> LibraryLoader();\n");
    output.write("Map<String, LibraryLoader> _deferredLibraries = {\n");
    for (var rawLocale in allLocales) {
      var locale = Intl.canonicalizedLocale(rawLocale);
      var loadOperation = (useDeferredLoading)
          ? "  '$locale': () => ${_libraryName(locale)}.loadLibrary(),\n"
          : "  '$locale': () => new Future.value(null),\n";
      output.write(loadOperation);
    }
    output.write("};\n");
    output.write("\nMessageLookupByLibrary _findExact(localeName) {\n"
        "  switch (localeName) {\n");
    for (var rawLocale in allLocales) {
      var locale = Intl.canonicalizedLocale(rawLocale);
      output.write(
          "    case '$locale':\n      return ${_libraryName(locale)}.messages;\n");
    }
    output.write(closing);
    return output.toString();
  }

  /// Constant string used in [generateMainImportFile] for the beginning of the
  /// file.
  get mainPrologue => """
// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that looks up messages for specific locales by
// delegating to the appropriate library.

import 'dart:async';

import 'package:$intlImportPath/intl.dart';
import 'package:$intlImportPath/message_lookup_by_library.dart';
// ignore: implementation_imports
import 'package:$intlImportPath/src/intl_helpers.dart';

""";

  /// Constant string used in [generateMainImportFile] as the end of the file.
  get closing => """
    default:\n      return null;
  }
}

/// User programs should call this before using [localeName] for messages.
Future initializeMessages(String localeName) async {
  var lib = _deferredLibraries[Intl.canonicalizedLocale(localeName)];
  await (lib == null ? new Future.value(false) : lib());
  initializeInternalMessageLookup(() => new CompositeMessageLookup());
  messageLookup.addLocale(localeName, _findGeneratedMessagesFor);
}

bool _messagesExistFor(String locale) {
  try {
    return _findExact(locale) != null;
  } catch (e) {
    return false;
  }
}

MessageLookupByLibrary _findGeneratedMessagesFor(locale) {
  var actualLocale = Intl.verifiedLocale(locale, _messagesExistFor,
      onFailure: (_) => null);
  if (actualLocale == null) return null;
  return _findExact(actualLocale);
}
""";
}

class JsonMessageGeneration extends MessageGeneration {
  /// We import the main file so as to get the shared code to evaluate
  /// the JSON data.
  String get extraImports => '''
import 'dart:convert';
import '${generatedFilePrefix}messages_all.dart' show evaluateJsonTemplate;
''';

  String prologue(locale) =>
      super.prologue(locale) +
      '''
  String evaluateMessage(translation, List args) {
    return evaluateJsonTemplate(translation, args);
  }
''';

  void writeTranslations(
      Iterable<TranslatedMessage> usableTranslations, String locale) {
    output.write(r"""
  var _messages;
  get messages =>
      _messages == null ? _messages = JSON.decode(messageText) : _messages;
""");

    output.write("  static final messageText = ");
    var entries = usableTranslations
        .expand((translation) => translation.originalMessages);
    var map = {};
    for (var original in entries) {
      map[original.name] = original.toJsonForLocale(locale);
    }
    output.write(
        "r'''\n" + new JsonEncoder.withIndent('  ').convert(map) + "''';\n}");
  }

  get closing =>
      super.closing +
      '''
/// Turn the JSON template into a string.
///
/// We expect one of the following forms for the template.
/// * null -> null
/// * String s -> s
/// * int n -> '\${args[n]}'
/// * List list, one of
///   * \['Intl.plural', int howMany, (templates for zero, one, ...)\]
///   * \['Intl.gender', String gender, (templates for female, male, other)\]
///   * \['Intl.select', String choice, { 'case' : template, ...} \]
///   * \['text alternating with ', 0 , ' indexes in the argument list'\]
String evaluateJsonTemplate(Object input, List args) {
  if (input == null) return null;
  if (input is String) return input;
  if (input is int) {
    return "\${args[input]}";
  }

  List template = input;
  var messageName = template.first;
  if (messageName == "Intl.plural") {
     var howMany = args[template[1]];
     return evaluateJsonTemplate(
         Intl.pluralLogic(
             howMany,
             zero: template[2],
             one: template[3],
             two: template[4],
             few: template[5],
             many: template[6],
             other: template[7]),
         args);
   }
   if (messageName == "Intl.gender") {
     var gender = args[template[1]];
     return evaluateJsonTemplate(
         Intl.genderLogic(
             gender,
             female: template[2],
             male: template[3],
             other: template[4]),
         args);
   }
   if (messageName == "Intl.select") {
     var select = args[template[1]];
     var choices = template[2];
     return evaluateJsonTemplate(Intl.selectLogic(select, choices), args);
   }

   // If we get this far, then we are a basic interpolation, just strings and
   // ints.
   var output = new StringBuffer();
   for (var entry in template) {
     if (entry is int) {
       output.write("\${args[entry]}");
     } else {
       output.write("\${entry}");
     }
   }
   return output.toString();
  }

 ''';
}

/// This represents a message and its translation. We assume that the
/// translation has some identifier that allows us to figure out the original
/// message it corresponds to, and that it may want to transform the translated
/// text in some way, e.g. to turn whatever format the translation uses for
/// variables into a Dart string interpolation. Specific translation mechanisms
/// are expected to subclass this.
abstract class TranslatedMessage {
  /// The identifier for this message. In the simplest case, this is the name
  /// parameter from the Intl.message call,
  /// but it can be any identifier that this program and the output of the
  /// translation can agree on as identifying a message.
  final String id;

  /// Our translated version of all the [originalMessages].
  final Message translated;

  /// The original messages that we are a translation of. There can
  ///  be more than one original message for the same translation.
  List<MainMessage> _originalMessages;

  List<MainMessage> get originalMessages => _originalMessages;
  set originalMessages(List<MainMessage> x) {
    _originalMessages = x;
  }

  /// For backward compatibility, we still have the originalMessage API.
  MainMessage get originalMessage => originalMessages.first;
  set originalMessage(MainMessage m) {
    originalMessages = [m];
  }

  TranslatedMessage(this.id, this.translated);

  Message get message => translated;

  toString() => id.toString();
}

/// We can't use a hyphen in a Dart library name, so convert the locale
/// separator to an underscore.
String _libraryName(String x) => 'messages_' + x.replaceAll('-', '_');

bool _hasArguments(MainMessage message) => message.arguments.length != 0;

///  Simple messages are printed directly in the map of message names to
///  functions as a call that returns a lambda. e.g.
///
///        "foo" : simpleMessage("This is foo"),
///
///  This is helpful for the compiler.
/// */
String _mapReference(MainMessage original, String locale) {
  if (!_hasArguments(original)) {
    // No parameters, can be printed simply.
    return 'MessageLookupByLibrary.simpleMessage("'
        '${original.translations[locale]}")';
  } else {
    return _methodNameFor(original.name);
  }
}

/// Generated method counter for use in [_methodNameFor].
int _methodNameCounter = 0;

/// A map from Intl message names to the generated method names
/// for their translated versions.
Map<String, String> _internalMethodNames = {};

/// Generate a Dart method name of the form "m<number>".
String _methodNameFor(String name) {
  return _internalMethodNames.putIfAbsent(
      name, () => "m${_methodNameCounter++}");
}
