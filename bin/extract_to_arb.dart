#!/usr/bin/env dart
// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// This script uses the extract_messages.dart library to find the Intl.message
/// calls in the target dart files and produces ARB format output. See
/// https://code.google.com/p/arb/wiki/ApplicationResourceBundleSpecification
library extract_to_arb;

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:intl_translation/extract_messages.dart';
import 'package:intl_translation/src/arb_generation.dart';
import 'package:intl_translation/src/directory_utils.dart';
import 'package:path/path.dart' as path;

void main(List<String> args) {
  String targetDir = '.';
  String outputFilename = 'intl_messages.arb';
  String? sourcesListFile;
  bool transformer = false;
  ArgParser parser = ArgParser();
  MessageExtraction extract = MessageExtraction();
  String? locale;
  parser.addFlag('suppress-last-modified',
      defaultsTo: false,
      callback: (x) => extract = extract.copyWith(suppressLastModified: x),
      help: 'Suppress @@last_modified entry.');
  parser.addFlag('suppress-warnings',
      defaultsTo: false,
      callback: (x) => extract = extract.copyWith(suppressWarnings: x),
      help: 'Suppress printing of warnings.');
  parser.addFlag('suppress-meta-data',
      defaultsTo: false,
      callback: (x) => extract = extract.copyWith(suppressMetaData: x),
      help: 'Suppress writing meta information');
  parser.addFlag('warnings-are-errors',
      defaultsTo: false,
      callback: (x) => extract = extract.copyWith(warningsAreErrors: x),
      help: 'Treat all warnings as errors, stop processing ');
  parser.addFlag('embedded-plurals',
      defaultsTo: true,
      callback: (x) =>
          extract = extract.copyWith(allowEmbeddedPluralsAndGenders: x),
      help: 'Allow plurals and genders to be embedded as part of a larger '
          'string, otherwise they must be at the top level.');
  parser.addFlag('transformer',
      callback: (x) => transformer = x,
      help: 'Assume that the transformer is in use, so name and args '
          "don't need to be specified for messages.");
  parser.addOption('locale',
      defaultsTo: null,
      callback: (value) => locale = value,
      help: 'Specify the locale set inside the arb file.');
  parser.addFlag('with-source-text',
      defaultsTo: false,
      callback: (x) => extract = extract.copyWith(includeSourceText: x),
      help: 'Include source_text in meta information.');
  parser.addOption(
    'output-dir',
    callback: (value) {
      if (value != null) targetDir = value;
    },
    help: 'Specify the output directory.',
  );
  parser.addOption(
    'output-file',
    callback: (value) {
      if (value != null) outputFilename = value;
    },
    help: 'Specify the output file.',
  );
  parser.addOption(
    'sources-list-file',
    callback: (value) => sourcesListFile = value,
    help: 'A file that lists the Dart files to read, one per line.'
        'The paths in the file can be absolute or relative to the '
        'location of this file.',
  );
  parser.addFlag(
    'require_descriptions',
    defaultsTo: false,
    help: "Fail for messages that don't have a description.",
    callback: (val) => extract = extract.copyWith(descriptionRequired: val),
  );

  parser.parse(args);
  if (args.isEmpty) {
    print('Accepts Dart files and produces $outputFilename');
    print('Usage: extract_to_arb [options] [files.dart]');
    print(parser.usage);
    exit(0);
  }
  Map<String, dynamic> allMessages = {};
  if (locale != null) {
    allMessages['@@locale'] = locale!;
  }
  if (!extract.suppressLastModified) {
    allMessages['@@last_modified'] = DateTime.now().toIso8601String();
  }

  List<String> dartFiles = [
    ...args.where((x) => x.endsWith('.dart')),
    ...linesFromFile(sourcesListFile)
  ];
  dartFiles
      .map((dartFile) => extract.parseFile(File(dartFile), transformer))
      .expand((parsedFile) => parsedFile.entries)
      .map((nameToMessage) => toARB(
            nameToMessage.value,
            includeSourceText: extract.includeSourceText,
            supressMetadata: extract.suppressMetaData,
          ))
      .forEach((message) => allMessages.addAll(message));
  File file = File(path.join(targetDir, outputFilename));
  JsonEncoder encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync(encoder.convert(allMessages));
  if (extract.hasWarnings && extract.warningsAreErrors) {
    exit(1);
  }
}
