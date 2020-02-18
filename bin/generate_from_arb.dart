#!/usr/bin/env dart
// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A main program that takes as input a source Dart file and a number
/// of ARB files representing translations of messages from the corresponding
/// Dart file. See extract_to_arb.dart and make_hardcoded_translation.dart.
///
/// If the ARB file has an @@locale or _locale value, that will be used as
/// the locale. If not, we will try to figure out the locale from the end of
/// the file name, e.g. foo_en_GB.arb will be assumed to be in en_GB locale.
///
/// This produces a series of files named
/// "messages_<locale>.dart" containing messages for a particular locale
/// and a main import file named "messages_all.dart" which has imports all of
/// them and provides an initializeMessages function.

library generate_from_arb;

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as path;

import 'package:intl_translation/extract_messages.dart';
import 'package:intl_translation/generate_localized.dart';
import 'package:intl_translation/src/directory_utils.dart';
import 'package:intl_translation/src/intl_message.dart';
import 'package:intl_translation/src/icu_parser.dart';

/// Keeps track of all the messages we have processed so far, keyed by message
/// name.
Map<String, List<MainMessage>> messages;

const jsonDecoder = const JsonCodec();

main(List<String> args) {
  var targetDir;
  var parser = new ArgParser();
  var extraction = new MessageExtraction();
  var generation = new MessageGeneration();
  String sourcesListFile;
  String translationsListFile;
  var transformer;
  parser.addFlag('json', defaultsTo: false, callback: (useJson) {
    generation =
        useJson ? new JsonMessageGeneration() : new MessageGeneration();
  }, help: 'Generate translations as a JSON string rather than as functions.');
  parser.addFlag("suppress-warnings",
      defaultsTo: false,
      callback: (x) => extraction.suppressWarnings = x,
      help: 'Suppress printing of warnings.');
  parser.addOption('output-dir',
      defaultsTo: '.',
      callback: (x) => targetDir = x,
      help: 'Specify the output directory.');
  parser.addOption("generated-file-prefix",
      defaultsTo: '',
      callback: (x) => generation.generatedFilePrefix = x,
      help: 'Specify a prefix to be used for the generated file names.');
  parser.addFlag("use-deferred-loading",
      defaultsTo: true,
      callback: (x) => generation.useDeferredLoading = x,
      help: 'Generate message code that must be loaded with deferred loading. '
          'Otherwise, all messages are eagerly loaded.');
  parser.addOption('codegen_mode',
      allowed: ['release', 'debug'],
      defaultsTo: 'debug',
      callback: (x) => generation.codegenMode = x,
      help: 'What mode to run the code generator in. Either release or debug.');
  parser.addOption("sources-list-file",
      callback: (value) => sourcesListFile = value,
      help: 'A file that lists the Dart files to read, one per line.'
          'The paths in the file can be absolute or relative to the '
          'location of this file.');
  parser.addOption("translations-list-file",
      callback: (value) => translationsListFile = value,
      help: 'A file that lists the translation files to process, one per line.'
          'The paths in the file can be absolute or relative to the '
          'location of this file.');
  parser.addFlag("transformer",
      defaultsTo: false,
      callback: (x) => transformer = x,
      help: "Assume that the transformer is in use, so name and args "
          "don't need to be specified for messages.");

  parser.parse(args);
  var dartFiles = args.where((x) => x.endsWith("dart")).toList();
  var jsonFiles = args.where((x) => x.endsWith(".arb")).toList();
  dartFiles.addAll(linesFromFile(sourcesListFile));
  jsonFiles.addAll(linesFromFile(translationsListFile));
  if (dartFiles.length == 0 || jsonFiles.length == 0) {
    print('Usage: generate_from_arb [options]'
        ' file1.dart file2.dart ...'
        ' translation1_<languageTag>.arb translation2.arb ...');
    print(parser.usage);
    exit(0);
  }

  // TODO(alanknight): There is a possible regression here. If a project is
  // using the transformer and expecting it to provide names for messages with
  // parameters, we may report those names as missing. We now have two distinct
  // mechanisms for providing names: the transformer and just using the message
  // text if there are no parameters. Previously this was always acting as if
  // the transformer was in use, but that breaks the case of using the message
  // text. The intent is to deprecate the transformer, but if this is an issue
  // for real projects we could provide a command-line flag to indicate which
  // sort of automated name we're using.
  extraction.suppressWarnings = true;
  var allMessages = dartFiles
      .map((each) => extraction.parseFile(new File(each), transformer));

  messages = new Map();
  for (var eachMap in allMessages) {
    eachMap.forEach(
        (key, value) => messages.putIfAbsent(key, () => []).add(value));
  }
  var messagesByLocale = <String, List<Map>>{};

  // In order to group these by locale, to support multiple input files,
  // we're reading all the data eagerly, which could be a memory
  // issue for very large projects.
  for (var arg in jsonFiles) {
    loadData(arg, messagesByLocale, generation);
  }

  messagesByLocale.forEach((locale, data) {
    generateLocaleFile(locale, data, targetDir, generation);
  });

  var mainImportFile = new File(path.join(
      targetDir, '${generation.generatedFilePrefix}messages_all.dart'));
  mainImportFile.writeAsStringSync(generation.generateMainImportFile());
}

loadData(String filename, Map<String, List<Map>> messagesByLocale,
    MessageGeneration generation) {
  var file = File(filename);
  var src = file.readAsStringSync();
  var data = jsonDecoder.decode(src);
  var locale = data["@@locale"] ?? data["_locale"];
  if (locale == null) {
    // Get the locale from the end of the file name. This assumes that the file
    // name doesn't contain any underscores except to begin the language tag
    // and to separate language from country. Otherwise we can't tell if
    // my_file_fr.arb is locale "fr" or "file_fr".
    var name = path.basenameWithoutExtension(file.path);
    locale = name.split("_").skip(1).join("_");
    print("No @@locale or _locale field found in $name, "
        "assuming '$locale' based on the file name.");
  }
  messagesByLocale.putIfAbsent(locale, () => []).add(data);
  generation.allLocales.add(locale);
}

/// Create the file of generated code for a particular locale.
///
/// We read the ARB
/// data and create [BasicTranslatedMessage] instances from everything,
/// excluding only the special _locale attribute that we use to indicate the
/// locale. If that attribute is missing, we try to get the locale from the
/// last section of the file name. Each ARB file produces a Map of message
/// translations, and there can be multiple such maps in [localeData].
void generateLocaleFile(String locale, List<Map> localeData, String targetDir,
    MessageGeneration generation) {
  List<TranslatedMessage> translations = [];
  for (var jsonTranslations in localeData) {
    jsonTranslations.forEach((id, messageData) {
      TranslatedMessage message = recreateIntlObjects(id, messageData);
      if (message != null) {
        translations.add(message);
      }
    });
  }
  generation.generateIndividualMessageFile(locale, translations, targetDir);
}

/// Regenerate the original IntlMessage objects from the given [data]. For
/// things that are messages, we expect [id] not to start with "@" and
/// [data] to be a String. For metadata we expect [id] to start with "@"
/// and [data] to be a Map or null. For metadata we return null.
BasicTranslatedMessage recreateIntlObjects(String id, data) {
  if (id.startsWith("@")) return null;
  if (data == null) return null;
  var parsed = pluralAndGenderParser.parse(data).value;
  if (parsed is LiteralString && parsed.string.isEmpty) {
    parsed = plainParser.parse(data).value;
  }
  return new BasicTranslatedMessage(id, parsed);
}

/// A TranslatedMessage that just uses the name as the id and knows how to look
/// up its original messages in our [messages].
class BasicTranslatedMessage extends TranslatedMessage {
  BasicTranslatedMessage(String name, translated) : super(name, translated);

  List<MainMessage> get originalMessages => (super.originalMessages == null)
      ? _findOriginals()
      : super.originalMessages;

  // We know that our [id] is the name of the message, which is used as the
  //key in [messages].
  List<MainMessage> _findOriginals() => originalMessages = messages[id];
}

final pluralAndGenderParser = new IcuParser().message;
final plainParser = new IcuParser().nonIcuMessage;
