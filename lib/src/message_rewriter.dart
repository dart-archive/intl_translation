// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Code to rewrite Intl.message calls adding the name and args parameters
/// automatically, primarily used by the transformer.
import 'package:analyzer/analyzer.dart';

import 'package:intl_translation/extract_messages.dart';

/// Rewrite all Intl.message/plural/etc. calls in [source], adding "name"
/// and "args" parameters if they are not provided.
///
/// Return the modified source code. If there are errors parsing, list
/// [sourceName] in the error message.
String rewriteMessages(String source, String sourceName,
    {useStringSubstitution: false}) {
  var messages = findMessages(source, sourceName);
  messages.sort((a, b) => a.sourcePosition.compareTo(b.sourcePosition));

  var start = 0;
  var newSource = new StringBuffer();
  for (var message in messages) {
    if (message.arguments.isNotEmpty) {
      newSource.write(source.substring(start, message.sourcePosition));
      if (useStringSubstitution) {
        rewriteWithStringSubstitution(newSource, source, start, message);
      } else {
        rewriteRegenerating(newSource, source, start, message);
      }
      start = message.endPosition;
    }
  }
  newSource.write(source.substring(start));
  return newSource.toString();
}

/// Rewrite the message by regenerating from our internal representation.
///
/// This may produce uglier source, but is more reliable.
rewriteRegenerating(StringBuffer newSource, String source, int start, message) {
  // TODO(alanknight): We could generate more efficient code than the
  // original here, dispatching more directly to the MessageLookup.
  newSource.write(message.toOriginalCode());
}

rewriteWithStringSubstitution(
    StringBuffer newSource, String source, int start, message) {
  var originalSource =
      source.substring(message.sourcePosition, message.endPosition);
  var closingParen = originalSource.lastIndexOf(')');
  // This is very ugly, checking to see if name/args is already there by
  // examining the source string. But at least the failure mode should
  // be very direct if we end up omitting name or args.
  var hasName = originalSource.contains(nameCheck);
  var hasArgs = originalSource.contains(argsCheck);
  var withName = hasName ? '' : ",\nname: '${message.name}'";
  var withArgs = hasArgs ? '' : ",\nargs: ${message.arguments}";
  var nameAndArgs = "$withName$withArgs)";
  newSource.write(originalSource.substring(0, closingParen));
  newSource.write(nameAndArgs);
  // We normally don't have anything after the closing paren, but
  // be safe.
  newSource.write(originalSource.substring(closingParen + 1));
}

final RegExp nameCheck = new RegExp('[\\n,]\\s+name\:');
final RegExp argsCheck = new RegExp('[\\n,]\\s+args\:');

/// Find all the messages in the [source] text.
///
/// Report errors as coming from [sourceName]
List findMessages(String source, String sourceName,
    [MessageExtraction extraction]) {
  extraction = extraction ?? new MessageExtraction();
  try {
    extraction.root = parseCompilationUnit(source, name: sourceName);
  } on AnalyzerErrorGroup catch (e) {
    extraction
        .onMessage("Error in parsing $sourceName, no messages extracted.");
    extraction.onMessage("  $e");
    return [];
  }
  extraction.origin = sourceName;
  var visitor = new MessageFindingVisitor(extraction);
  visitor.generateNameAndArgs = true;
  extraction.root.accept(visitor);
  return visitor.messages.values.toList();
}
