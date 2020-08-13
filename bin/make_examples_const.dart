#!/usr/bin/env dart
// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Converts the examples parameter for Intl messages to be const.
import 'dart:io';

import 'package:args/args.dart';
import 'package:dart_style/dart_style.dart';
import 'package:intl_translation/src/message_rewriter.dart';

main(List<String> args) {
  var parser = new ArgParser();
  var rest = parser.parse(args).rest;
  if (rest.length == 0) {
    print('Accepts Dart file paths and rewrites the examples to be const '
        'in Intl.message calls.');
    print('Usage: make_examples_const [options] [file.dart]...');
    print(parser.usage);
    exit(0);
  }

  var formatter = new DartFormatter();
  for (var inputFile in rest) {
    var outputFile = inputFile;
    var file = new File(inputFile);
    var content = file.readAsStringSync();
    var newSource = rewriteMessages(content, '$file');
    if (content == newSource) {
      print('No changes to $outputFile');
    } else {
      print('Writing new source to $outputFile');
      var out = new File(outputFile);
      out.writeAsStringSync(formatter.format(newSource));
    }
  }
}

/// Rewrite all Intl.message/plural/etc. calls in [source] which have
/// examples, making them be const.
///
/// Return the modified source code. If there are errors parsing, list
/// [sourceName] in the error message.
String rewriteMessages(String source, String sourceName) {
  var messages = findMessages(source, sourceName);
  messages.sort((a, b) => a.sourcePosition.compareTo(b.sourcePosition));
  var start = 0;
  var newSource = new StringBuffer();
  for (var message in messages) {
    if (message.examples != null) {
      newSource.write(source.substring(start, message.sourcePosition));
      rewrite(newSource, source, start, message);
      start = message.endPosition;
    }
  }
  newSource.write(source.substring(start));
  return newSource.toString();
}

void rewrite(StringBuffer newSource, String source, int start, message) {
  var originalSource =
      source.substring(message.sourcePosition, message.endPosition);
  var examples = nonConstExamples.firstMatch(originalSource);
  if (examples == null) {
    newSource.write(originalSource);
  } else {
    var modifiedSource = originalSource.replaceFirst(
        examples.group(1), examples.group(1) + 'const');
    newSource.write(modifiedSource);
  }
}

final RegExp nonConstExamples = new RegExp('([\\n,]\\s+examples\: ){');
